// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import WebKit

// MARK: - CollectionPreviewView

/// Live HTML preview of a collection — "the HTML export, live" (Authoring Phase 2b, A2).
///
/// Resolves the collection through `CollectionContentResolver` with purpose `.preview`
/// (never downloads volumes, never triggers AI generation) and assembles the page with
/// `CollectionItemHTMLRenderer.pageHTML` — the exact assembly the HTML export writes to
/// disk — so the preview and the export cannot drift by construction. The page is shown
/// in a `WKWebView`.
///
/// ## Debounce
/// Re-resolution is keyed on a `Hashable` fingerprint of every stored property of the collection and
/// its entries that the page is drawn from (`CollectionPreviewRefresh`), with the active project when
/// the page names it, via `.task(id:)`. Edits settle for ~1 second before a re-resolve runs; the
/// first render and explicit user actions (Render All, a row chosen past the cap, download completion)
/// skip the debounce. A superseded resolve is cancelled by SwiftUI and discards its result.
///
/// ## The fingerprint's list (L36, #1997)
/// Until L36 the fingerprint was a list kept by hand, and it had fallen behind the page: an entry's
/// title override, the collection's Headnotes default, its project stamp and its query log were drawn
/// and not hashed, so switching one alone left the page as it was. `CollectionPreviewRefresh` names
/// each stored property the page does not draw, with why, and `CollectionPreviewRefreshListTests`
/// walks both models' stored properties: each that is not named moves the fingerprint, and each that
/// is named does not. A property added to either model fails it until it is hashed or named.
///
/// ## The reader's place and the chosen row (L36)
/// The page keeps the reader's place when it loads again: it reports where the reader stopped
/// scrolling (the document at the top of the view and how far into it), and a new page lands there,
/// in the document the reader was in, wherever the text above it has grown or shrunk. Choosing a row in
/// the outline brings its document into view, rendering through it first when it is past the cap. Both
/// live in `CollectionPreviewPlace`, which the editor holds, so they outlive a preview the iPhone's
/// Outline | Preview control builds again. A document entered twice is two places on the page (#2004),
/// so a chosen row brings its own copy into view.
///
/// ## Stored rows no entry holds (#1765)
/// The page also draws rows the entries only point at — a document's summaries (its headnote,
/// summary-only depth), its highlights, its notes and its tags — and those are written elsewhere: a
/// summary by `SummarizationService` in a context of its own, a highlight or a note in the reader,
/// in any window. A hidden, always-mounted `CollectionPreviewUserDataObserver` follows them with live
/// `@Query`s scoped to the preview's documents, and a change it reports re-resolves the page through
/// the same debounce. Before, the fingerprint saw none of them, and the Mac's Collections window kept
/// *No stored summary for this document* beside an inspector that listed the summary.
///
/// ## Initial render cap
/// At most `initialDocumentCap` document items are resolved/rendered initially; larger
/// collections show a native bar with a **Render All** button that lifts the cap for the
/// editor session (the flag is owned by the presenting editor so pane toggles keep it).
/// Both paths cap *before* per-document resolution, so the parse cost of documents past
/// the cap is never paid: static collections cap the entry list; smart collections fetch
/// the lightweight search-result refs (`CollectionContentResolver.smartRefs`), cap those,
/// and resolve only the capped refs — the true result count still drives the cap bar.
///
/// ## Un-downloaded volumes
/// `.preview` resolution yields citation-only items for documents in un-downloaded
/// volumes; those render as a distinct bordered citation card in the HTML (see
/// `CollectionItemHTMLRenderer.citationOnlyVolumeIds`). The download affordance is
/// native: a bar above the web view names the missing-volume count and offers a
/// **Download** button that enqueues them via the existing `DownloadManager` path.
/// Whenever any volumes are missing — regardless of how a download was started (the
/// preview's own button, the editor's Export, the Browser) — a `.task`-scoped poll
/// watches for their arrival and refreshes the preview, so citation cards never go
/// stale while the pane is open. Missing volumes with no manifest entry cannot be
/// downloaded: they are named in a "not available" note instead of a dead button.
///
/// The web-view shell is a minimal local representable rather than the
/// `FRUSDocumentWebView`/`FRUSWebViewConfiguration` stack deliberately: the preview page
/// is the export HTML, which carries no `frusexplorer://` interactive links and needs no
/// offset-engine/highlight/selection JS — only external-link routing to the system
/// browser (same navigation-delegate posture as `FRUSDocumentWebView`), and, since L36, the
/// small script that reports and restores the reader's place, which the web view adds at load.
///
/// Per-item incremental DOM patching is out of scope here: each refresh loads the whole page,
/// and the reader's place is what survives it (L36).
///
/// Version history:
///   1.0 — Authoring Phase 2b: initial implementation (debounced full-page regeneration,
///          25-document initial cap, native missing-volume download bar, honest
///          HTML-fidelity caption)
///   1.1 — Authoring Phase 2b (adversarial-review fixes): smart collections cap the
///          search-result refs *before* per-document resolution (was: resolve the full
///          result set, then cap); initial cap lowered 25 → 20 to fit inside the
///          24-slot `DocumentASTCache` LRU; superseded resolves cancel cooperatively
///          (resolver v1.1) and their `CancellationError` is discarded silently;
///          `.summaryOnly` documents without a stored summary render a placeholder card
///          (renderer v1.2); the volume-arrival poll runs whenever volumes are missing,
///          not only after the preview's own Download button; missing volumes absent
///          from the manifest surface a "not available" note and never produce a
///          phantom downloading state
///   1.2 — Authoring Phase 5 (excerpts): the content fingerprint covers the excerpt
///          anchor fields (`excerptStart`/`excerptEnd`/`excerptRenderingVersion`/
///          `excerptColorTag`); excerpt rendering itself arrives free via the shared
///          `CollectionItemHTMLRenderer`
///   1.3 — Authoring Phase 5 (overrides): the fingerprint covers the per-entry override
///          fields (`applyHighlightsOverride`/`includeNotesOverride`/
///          `includeSourceNoteOverride`/`includeFootnotesOverride`/
///          `summaryPromptIdOverride`/`selectedHighlightIds`/`includeRelatedDocuments`),
///          so toggling any inspector override live-refreshes the page; the rendering
///          itself arrives via the shared renderer and resolver cascade
///   1.4 — Authoring Phase 6 (generated apparatus): the fingerprint covers
///          `generatedBlockType`, so inserting/moving/deleting an apparatus block
///          live-refreshes; block rendering arrives free via the shared renderer
///   1.5 — Authoring Phase 6 review fixes: `capEntries` exempts `.generated` entries —
///          apparatus blocks cost bounded index queries, never the XML parse the cap
///          exists to avoid, and back-matter blocks default-insert at the very end
///          (exactly the capped-out region), so without the exemption a new block was
///          invisible in every capped preview despite the row caption's promise; the
///          smart path passes the uncapped refs as `fullRefs`, so generated blocks
///          (and the A10 membership) reflect the full result set even under the cap
///   1.6 — #1463: the page's metadata comes from the export sheet's builder,
///          `CollectionExportMetadata.forExport`, in place of a copy with its own
///          "Untitled Collection" fallback — so the preview and the exported file carry one title
///   1.7 — 2026-10-25 (FRUS Explorer Light, S18a): the renderer is FRUSCoreKit's, and the preview hands it the
///          app's figure store, which was its default
///   1.8 — #1765: the page re-resolves when a summary, highlight, note or tag assignment of one of its
///          documents is stored, from any window (`CollectionPreviewUserDataObserver`)
///   1.9 — L36 (#1997, #2004; the Collections design's §5.3): the fingerprint hashes every stored property
///          the page draws (`CollectionPreviewRefresh`), an entry's title override, the Headnotes default,
///          the project stamp and the query log among them, with the active project when the page names
///          it; the page keeps the reader's place when it loads again, and a chosen row brings its own
///          document into view, past the cap too (`CollectionPreviewPlace`); the export options are the
///          export sheet's (`ExportFormat.exportOptions(for:)`), without the word cloud
struct CollectionPreviewView: View {

    // MARK: - Inputs

    /// The collection being previewed (composition fields are part of the fingerprint).
    let collection: Collection

    /// The collection's ordered entries (ignored by resolution for smart collections).
    let entries: [CollectionEntry]

    /// All research notes, for resolving entry note links.
    let allNotes: [ResearchNote]

    /// Lifts the initial document cap when `true`. Owned by the presenting editor so
    /// the "session" survives Outline/Preview pane toggles that recreate this view.
    @Binding var renderAll: Bool

    /// The reader's place on the page and the row last chosen in the outline (L36). Owned by the
    /// presenting editor, like `renderAll`, so a preview built again lands where the last one was.
    let place: CollectionPreviewPlace

    // MARK: - Environment

    /// Shared services: manifest store, download manager, indexing pipeline, AST cache.
    @Environment(AppState.self) private var appState

    /// SwiftData context handed to the resolver for user-data lookups.
    @Environment(\.modelContext) private var modelContext

    /// All projects, to resolve the active project for the preview's export provenance (#377
    /// Phase 4) — the live preview must match the exported file.
    @Query(sort: \Project.name) private var allProjects: [Project]

    /// The active project (the source of export provenance), or `nil` in Global Context.
    private var activeProject: Project? { allProjects.first { $0.id == appState.activeProjectId } }

    // MARK: - Constants

    /// Maximum number of document items resolved/rendered before the user asks for all.
    ///
    /// Deliberately **below** `DocumentASTCache`'s 24-slot LRU capacity: a capped preview
    /// re-resolves the same documents sequentially on every refresh, and a scan of 25+
    /// documents through a 24-slot LRU evicts each entry just before its next use — the
    /// textbook LRU worst case, missing (and re-parsing) every document every refresh.
    /// At 20 the whole capped set stays resident, so refreshes after the first are all
    /// cache hits. Keep this under the cache capacity; do not "fix" it by growing the
    /// app-wide cache, which is sized for reading windows.
    static let initialDocumentCap = 20

    // MARK: - State

    /// The most recently assembled full HTML page; `nil` until the first resolve lands.
    @State private var html: String?

    /// `true` while a resolve/render pass is running (drives the progress indicator).
    @State private var isResolving = false

    /// `true` once any render has completed — the first render skips the debounce.
    @State private var hasRenderedOnce = false

    /// One-shot debounce skip for explicit user actions (Render All, download arrival).
    @State private var skipDebounceOnce = false

    /// Total number of document items in the collection (pre-cap), for the cap bar.
    @State private var totalDocumentCount = 0

    /// Volume ids referenced by the collection that are not downloaded locally.
    @State private var missingVolumeIds: Set<String> = []

    /// The subset of `missingVolumeIds` with no manifest entry — volumes that cannot be
    /// downloaded by any path. Named in the bar's "not available" note; excluded from
    /// the Download affordance and the arrival poll.
    @State private var unavailableVolumeIds: Set<String> = []

    /// `true` after the user tapped Download, until the poll sees the volumes arrive.
    @State private var downloadsInFlight = false

    /// Bumped by out-of-band events (download completion) to force a re-resolve.
    @State private var refreshToken = 0

    /// Non-nil when the last resolve failed; shown natively in place of the page.
    @State private var resolveError: String?

    /// A smart collection's documents as its last resolve found them: the user-data observer's scope,
    /// which a static collection reads from its entries instead (#1765). `nil` before the first resolve.
    @State private var smartScope: CollectionPreviewUserDataScope?

    /// What the user-data observer last reported, which tells a change from a new scope's baseline.
    @State private var userDataWatch = CollectionPreviewUserDataWatch()

    /// The scope of stored rows the page draws: a smart collection's last-resolved documents, or a
    /// static collection's document entries and the notes its entries name.
    private var userDataScope: CollectionPreviewUserDataScope {
        collection.savedSearchId != nil
            ? (smartScope ?? .empty)
            : CollectionPreviewUserDataScope(entries: entries)
    }

    // MARK: - Fingerprint

    /// How many documents the page is rendered through: `initialDocumentCap`, raised to a chosen row
    /// past it (L36), or every one, `nil`, once Render All is pressed.
    private var documentCap: Int? {
        renderAll ? nil : max(Self.initialDocumentCap, place.revealedCap)
    }

    /// Hash of everything the rendered page depends on (`CollectionPreviewRefresh.fingerprint`): every
    /// stored property of the collection and its entries that the page draws, what it names of the
    /// active project, and the cap. Reading these observable properties during body evaluation also
    /// registers the SwiftUI dependencies that re-run the `.task` when they change.
    private var contentFingerprint: Int {
        CollectionPreviewRefresh.fingerprint(
            collection: collection, entries: entries,
            project: CollectionPreviewRefresh.ProjectKey(collection: collection, activeProject: activeProject),
            documentCap: documentCap, refreshToken: refreshToken)
    }

    /// The chosen row's document, to bring into view: its anchor on the page and the choice that asked,
    /// or `nil` when no row is chosen or the chosen row is not a document's (L36).
    private var reveal: CollectionPreviewReveal? {
        guard collection.savedSearchId == nil, let chosen = place.chosen,
              let target = Self.revealTarget(of: chosen.entryId, in: entries) else { return nil }
        return CollectionPreviewReveal(anchor: target.anchor, serial: chosen.serial)
    }

    /// The anchor of `entryId`'s document on the page, and its place among the collection's document
    /// entries, counted as `capEntries(_:cap:)` counts them; `nil` when the entry is not a document's.
    ///
    /// The anchor is the renderer's own numbering (`CollectionItemHTMLRenderer.anchorIds(forKeys:)`),
    /// read over the entries in the order the resolver gives the page, so a document entered twice
    /// brings the copy that was chosen into view (#2004). An entry with no volume or document id is
    /// left out of the page by the resolver, and of the numbering here.
    ///
    /// Internal (not private) so tests can hold it to the page without a WebKit view.
    static func revealTarget(of entryId: UUID, in entries: [CollectionEntry]) -> (anchor: String, ordinal: Int)? {
        var ordinal = 0
        var keys: [(volumeId: String, documentId: String)] = []
        for entry in entries.sorted(by: { $0.sortOrder < $1.sortOrder }) where entry.entryKind == .document {
            ordinal += 1
            let printed = !entry.volumeId.isEmpty && !entry.documentId.isEmpty
            if printed { keys.append((volumeId: entry.volumeId, documentId: entry.documentId)) }
            guard entry.id == entryId else { continue }
            guard printed, let anchor = CollectionItemHTMLRenderer.anchorIds(forKeys: keys).last else { return nil }
            return (anchor, ordinal)
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !missingVolumeIds.isEmpty {
                missingVolumesBar
                Divider()
            }
            if let cap = documentCap, totalDocumentCount > cap {
                capBar(cap)
                Divider()
            }
            previewSurface
            Divider()
            fidelityFooter
        }
        // Debounced re-resolve/re-render whenever the fingerprint changes. A newer
        // fingerprint cancels the in-flight pass during its debounce sleep (or its
        // result is discarded via the cancellation check before state assignment).
        .task(id: contentFingerprint) {
            await refresh()
        }
        // L36: a row chosen past the cap is rendered through, so its document can be brought into view.
        // `initial`: a preview the iPhone builds again reads the row chosen while it was away.
        .onChange(of: place.chosen, initial: true) { _, chosen in
            guard collection.savedSearchId == nil, let chosen, chosen.serial != place.revealedSerial,
                  let cap = documentCap, let target = Self.revealTarget(of: chosen.entryId, in: entries),
                  target.ordinal > cap else { return }
            skipDebounceOnce = true
            place.revealedCap = target.ordinal
        }
        // Whenever volumes are missing, poll until they arrive — via the preview's own
        // Download button OR any other path (the editor's Export, the Browser) — then
        // force a refresh so the citation cards never go stale. Keyed on the missing
        // set; `.task`-scoped, so it cancels with the pane.
        .task(id: missingVolumeIds) {
            await pollForVolumeArrivals()
        }
        // #1765: a summary, highlight, note or tag assignment of one of the page's documents, stored
        // from any window, re-resolves the page. Re-created when the scope moves, and a new scope's
        // first report is a baseline, not a change: the resolve that moved it already read those rows.
        .background {
            CollectionPreviewUserDataObserver(scope: userDataScope) { scope, digest in
                if userDataWatch.record(digest, over: scope) {
                    refreshToken += 1
                }
            }
            .id(userDataScope)
        }
    }

    // MARK: - Preview surface

    /// The web view (or its loading/error placeholders) with a progress overlay while
    /// a re-resolve runs, so the last-good page stays visible during regeneration.
    @ViewBuilder
    private var previewSurface: some View {
        ZStack(alignment: .center) {
            if let error = resolveError {
                ContentUnavailableView {
                    Label(String(localized: "collection.preview.error.title",
                                 defaultValue: "Preview Unavailable"),
                          systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if let html {
                CollectionPreviewWebView(html: html, collectionId: collection.id, reveal: reveal, place: place)
            } else {
                ProgressView(String(localized: "collection.preview.loading",
                                    defaultValue: "Building preview…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isResolving && html != nil && resolveError == nil {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .topTrailing)
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Native bars

    /// Bar naming the number of un-downloaded volumes with a Download button that
    /// enqueues them through the existing `DownloadManager` path (native affordance —
    /// no in-page JS). Missing volumes with no manifest entry cannot be downloaded:
    /// they get a "not available" caption instead, and when *every* missing volume is
    /// unavailable no Download button is shown at all.
    private var missingVolumesBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                let count = missingVolumeIds.count
                Label(
                    String(localized: "collection.preview.missingVolumes",
                           defaultValue: "\(count) volume\(count == 1 ? "" : "s") not downloaded"),
                    systemImage: "arrow.down.circle"
                )
                .font(.callout)
                Spacer()
                if downloadsInFlight {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "collection.preview.downloading",
                                    defaultValue: "Downloading…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if !missingVolumeIds.subtracting(unavailableVolumeIds).isEmpty {
                    Button(String(localized: "collection.preview.download",
                                  defaultValue: "Download")) {
                        downloadMissingVolumes()
                    }
                    .font(.callout)
                }
            }
            if !unavailableVolumeIds.isEmpty {
                let unavailable = unavailableVolumeIds.count
                Text(String(localized: "collection.preview.volumesUnavailable",
                            defaultValue: "\(unavailable) volume\(unavailable == 1 ? " is" : "s are") not available for download"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Bar shown when the collection exceeds the document cap, with the
    /// Render All button that lifts it for the editor session. The "of M" total is the
    /// true document count — for smart collections, the full search-result count, even
    /// though only the capped prefix was resolved. The cap is the initial one, or the
    /// chosen row's place when a row past it was chosen (L36).
    private func capBar(_ cap: Int) -> some View {
        HStack(spacing: 12) {
            Text(String(localized: "collection.preview.capNotice",
                        defaultValue: "Showing first \(cap) of \(totalDocumentCount) documents"))
                .font(.callout)
            Spacer()
            Button(String(localized: "collection.preview.renderAll",
                          defaultValue: "Render All")) {
                skipDebounceOnce = true
                renderAll = true
            }
            .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// The honest-fidelity caption (A2): this is a reader proof, not a page proof.
    private var fidelityFooter: some View {
        Text(String(localized: "collection.preview.fidelityNote",
                    defaultValue: "Preview of the HTML export — PDF and Word pagination will differ"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
    }

    // MARK: - Resolution

    /// One debounced resolve/render pass: waits ~1 s for edits to settle (skipped on
    /// the first render and after explicit user actions), recomputes the missing-volume
    /// set, resolves via `CollectionContentResolver(.preview)` honoring the document
    /// cap, and assembles the page with the shared `CollectionItemHTMLRenderer`.
    private func refresh() async {
        if hasRenderedOnce && !skipDebounceOnce {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
        }
        skipDebounceOnce = false
        isResolving = true
        defer { isResolving = false }

        // Missing volumes — static collections only: smart results come from the FTS5
        // index, so their volumes are present by construction.
        let isSmart = collection.savedSearchId != nil
        var missing: Set<String> = []
        if !isSmart, let dm = appState.downloadManager {
            let neededVolumeIds = Set(
                entries.filter { $0.entryKind == .document && !$0.volumeId.isEmpty }
                    .map(\.volumeId))
            missing = neededVolumeIds.filter { !dm.isVolumeDownloaded($0) }
        }
        // Missing volumes with no manifest entry can never be downloaded — surfaced as
        // a "not available" note instead of a dead Download affordance.
        let manifestVolumeIds = Set(
            (appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries)
                .map(\.volumeId))
        let unavailable = missing.filter { !manifestVolumeIds.contains($0) }

        let resolver = CollectionContentResolver(appState: appState, modelContext: modelContext)
        let cap = documentCap
        do {
            let items: [CollectionExportItem]
            if isSmart {
                // Smart path: fetch the lightweight search-result refs (an FTS5 query —
                // no parsing), cap them BEFORE per-document resolution so at most the
                // cap is ever parsed, and keep the true total for the cap bar.
                let refs = try await resolver.smartRefs(for: collection)
                let docCount = refs.count
                let cappedRefs = cap.map { docCount <= $0 ? refs : Array(refs.prefix($0)) } ?? refs
                let resolved = try await resolver.resolve(
                    smartRefs: cappedRefs, collection: collection, allNotes: allNotes,
                    purpose: .preview, fullRefs: refs)
                if Task.isCancelled { return }
                totalDocumentCount = docCount
                smartScope = CollectionPreviewUserDataScope(refs: refs)
                items = resolved
            } else {
                // Static path: cap the entries *before* resolution so the parse cost of
                // documents past the cap is never paid.
                let docCount = entries.filter { $0.entryKind == .document }.count
                let cappedEntries = cap.map { docCount <= $0 ? entries : Self.capEntries(entries, cap: $0) } ?? entries
                let resolved = try await resolver.resolve(
                    collection: collection, entries: cappedEntries, allNotes: allNotes,
                    purpose: .preview)
                if Task.isCancelled { return }
                totalDocumentCount = docCount
                items = resolved
            }

            var renderer = CollectionItemHTMLRenderer(options: previewOptions())
            renderer.figureImages = FigureImageStore.shared
            renderer.citationOnlyVolumeIds = missing
            renderer.showsSummaryPlaceholders = true
            // The export sheet's own builder (#1463), so the preview's title is the exported file's.
            let metadata = CollectionExportMetadata.forExport(
                of: collection, activeProject: activeProject, modelContext: modelContext)
            let page = renderer.pageHTML(metadata: metadata, items: items)
            if Task.isCancelled { return }
            missingVolumeIds = missing
            unavailableVolumeIds = unavailable
            html = page
            resolveError = nil
            hasRenderedOnce = true
        } catch is CancellationError {
            // Superseded by a newer fingerprint — the resolver stopped cooperatively
            // (resolver v1.1); discard silently, the newer pass owns the state.
            return
        } catch {
            if Task.isCancelled { return }
            missingVolumeIds = missing
            unavailableVolumeIds = unavailable
            resolveError = error.localizedDescription
        }
    }

    /// The export sheet's options for a web page (`ExportFormat.exportOptions(for:)`), minus the word
    /// cloud (export-only decoration). Until L36 the preview built them by hand, seven of the eight
    /// fields `init(composing:)` reads, so a field the options gain reached the export and not the preview.
    private func previewOptions() -> CollectionExportOptions {
        var options = ExportFormat.html.exportOptions(for: collection)
        options.includeWordCloud = false
        return options
    }

    /// Returns the entry prefix (in `sortOrder` order) containing at most `cap`
    /// document entries — interleaved headings/prose before the cut are kept, and
    /// `.generated` apparatus entries survive the cap wherever they sit (v1.5): they
    /// cost bounded index queries, never the per-document XML parse the cap exists to
    /// avoid, and the back-matter types default-insert past any cap — without the
    /// exemption a freshly added bibliography was invisible in every capped preview.
    /// Their rows still reflect the FULL membership (the resolver computes block
    /// membership from the collection, not the passed prefix), so a capped preview's
    /// blocks match the export's.
    ///
    /// Internal (not private) so tests can pin the cap semantics without a WebKit view.
    static func capEntries(_ entries: [CollectionEntry], cap: Int) -> [CollectionEntry] {
        var documentCount = 0
        var out: [CollectionEntry] = []
        for entry in entries.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if entry.entryKind == .document { documentCount += 1 }
            if documentCount > cap {
                if entry.entryKind == .generated { out.append(entry) }
                continue
            }
            out.append(entry)
        }
        return out
    }

    // MARK: - Downloads

    /// Enqueues every *downloadable* missing volume (those with a manifest entry) through
    /// the existing `DownloadManager` path — the same enqueue used by the Browser's volume
    /// rows. Volumes with no manifest entry are already surfaced via the bar's "not
    /// available" note; the downloading state is entered only when at least one download
    /// was actually enqueued, so a manifest-less set can never show a phantom
    /// "Downloading…". Arrival is observed by the always-on `pollForVolumeArrivals`.
    private func downloadMissingVolumes() {
        guard let dm = appState.downloadManager else { return }
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        var enqueuedAny = false
        for volumeId in missingVolumeIds.subtracting(unavailableVolumeIds) {
            // #777: `manifest` is the catalogue, so a side-loaded volume never appears here —
            // and could not be downloaded if it did. `enqueueDownload(_:)` declines it anyway,
            // so `enqueuedAny` must not be set before the entry proves fetchable, or the preview
            // would spin on a download that was never queued.
            guard let entry = manifest.first(where: { $0.volumeId == volumeId }),
                  entry.downloadUrl != nil else { continue }
            enqueuedAny = true
            Task { await dm.enqueueDownload(entry) }
        }
        if enqueuedAny {
            downloadsInFlight = true
        }
    }

    /// Polls (2 s interval, ~5 min budget) while any missing volume could still arrive,
    /// regardless of what started the download — the preview's own Download button, the
    /// same editor's Export, or the Browser. When every arrivable volume (those with a
    /// manifest entry) is downloaded, bumps `refreshToken` so the preview re-resolves
    /// without the debounce. Keyed on `missingVolumeIds` from the view's `.task`, so it
    /// restarts when the missing set changes and cancels when the pane closes.
    private func pollForVolumeArrivals() async {
        guard let dm = appState.downloadManager else { return }
        // Volumes absent from the manifest can never arrive; wait only on those that can.
        let manifestVolumeIds = Set(
            (appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries)
                .map(\.volumeId))
        let waiting = missingVolumeIds.filter { manifestVolumeIds.contains($0) }
        guard !waiting.isEmpty else { return }
        for _ in 0..<150 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            if waiting.allSatisfy({ dm.isVolumeDownloaded($0) }) {
                downloadsInFlight = false
                skipDebounceOnce = true
                refreshToken += 1
                return
            }
        }
        downloadsInFlight = false
    }
}

// MARK: - The reader's place and the chosen row (L36)

/// Where the reader is on a collection's preview, and the row last chosen in its outline (L36; the
/// Collections design's §5.3).
///
/// Held by the editor that shows the preview, as its Render All is, so that a preview built again (the
/// iPhone's Outline | Preview control builds one each time it shows the page) lands where the last one
/// was, and reads a row chosen while it was away. A row is chosen by its selection on the Mac and by
/// opening its settings on iPad and iPhone: `choose(_:)`.
@MainActor @Observable
final class CollectionPreviewPlace {

    /// A place on the page: the document whose section holds the top of the view, and how far into it
    /// the view begins, or, above every document, how far down the page.
    struct Mark: Codable, Equatable, Sendable {
        /// The section's anchor; `nil` above the first document (the title page and the contents).
        var anchor: String?
        /// How far the top of the view is below the section's top, in CSS pixels.
        var offset: Double
        /// How far the page is scrolled, in CSS pixels: the place when there is no section.
        var y: Double

        /// The place a page reported, from its message body; `nil` for a body of another shape.
        init?(messageBody body: Any) {
            guard let fields = body as? [String: Any],
                  let offset = (fields["offset"] as? NSNumber)?.doubleValue,
                  let y = (fields["y"] as? NSNumber)?.doubleValue else { return nil }
            self.init(anchor: fields["anchor"] as? String, offset: offset, y: y)
        }

        /// A place of these values.
        init(anchor: String?, offset: Double, y: Double) {
            self.anchor = anchor
            self.offset = offset
            self.y = y
        }
    }

    /// A row chosen in the outline, numbered so that choosing it again brings it back into view.
    struct Choice: Equatable, Sendable {
        /// The chosen entry.
        let entryId: UUID
        /// One more than the choice before it.
        let serial: Int
    }

    /// The row last chosen, whose document the preview brings into view. Observed, so a choice
    /// re-renders the preview.
    private(set) var chosen: Choice?

    /// How many documents a chosen row past the cap had the page rendered through (`0` before any).
    /// Observed: the fingerprint reads it, so raising it renders the page again.
    var revealedCap = 0

    /// The choice whose document was brought into view, so a preview built again does not bring it
    /// again over the place the reader has since scrolled to.
    @ObservationIgnored var revealedSerial: Int?

    /// The last place the page reported, and the collection it is a place in. Not observed: the page
    /// reports one each time the reader stops scrolling, and nothing on screen is drawn from it.
    @ObservationIgnored private var lastMark: Mark?
    @ObservationIgnored private var lastMarkCollectionId: UUID?

    /// An empty place: the top of the page, no row chosen.
    init() {}

    /// Chooses `entryId`'s row, whose document the preview brings into view; `nil` chooses nothing.
    func choose(_ entryId: UUID?) {
        guard let entryId else { return }
        chosen = Choice(entryId: entryId, serial: (chosen?.serial ?? 0) + 1)
    }

    /// Records `mark` as the reader's place on `collectionId`'s page.
    func record(_ mark: Mark, in collectionId: UUID) {
        lastMark = mark
        lastMarkCollectionId = collectionId
    }

    /// The reader's place on `collectionId`'s page, or `nil` when the last place was on another's.
    func mark(in collectionId: UUID) -> Mark? {
        lastMarkCollectionId == collectionId ? lastMark : nil
    }
}

/// A chosen row's document to bring into view: its anchor on the page, and the choice that asked.
struct CollectionPreviewReveal: Equatable, Sendable {
    /// The document's section, its entry's own (`CollectionItemHTMLRenderer.anchorIds(forKeys:)`).
    let anchor: String
    /// `CollectionPreviewPlace.Choice.serial`.
    let serial: Int
}

// MARK: - The fingerprint's list (L36, #1997)

/// What a collection's preview re-resolves on: every stored property of the collection and its entries
/// that the page is drawn from, and what the page names of the active project (L36, #1997).
///
/// **The list is checked, not only kept by hand** (J20). `CollectionPreviewRefreshListTests` walks the
/// stored properties of `Collection` and `CollectionEntry`: each one that ``collectionPropertiesNotDrawn``
/// and ``entryPropertiesNotDrawn`` do not name must move the fingerprint when it alone is changed, and
/// each one they name must not. A property added to either model fails the suite until it is hashed
/// here or named there, with why. Until L36 no test read the list, and four properties the page draws
/// had fallen out of it: an entry's title override, the Headnotes default, the project stamp's switch
/// and the query log's.
enum CollectionPreviewRefresh {

    /// What the page names of the active project, which no stored property of the collection holds.
    struct ProjectKey: Hashable, Sendable {
        /// The stamped project's name, when the collection stamps the title page with it.
        let stampName: String?
        /// The stamped project's research question, when the collection stamps the title page with it.
        let stampQuestion: String?
        /// The project whose queries the method appendix lists, when the collection prints it.
        let appendixProjectId: UUID?

        /// What `collection`'s page names of `activeProject`, as `CollectionExportMetadata.forExport` reads it.
        @MainActor
        init(collection: Collection, activeProject: Project?) {
            stampName = collection.includeProjectProvenance ? activeProject?.name : nil
            stampQuestion = collection.includeProjectProvenance ? activeProject?.researchQuestion : nil
            appendixProjectId = collection.includeMethodAppendix ? activeProject?.id : nil
        }

        /// Nothing of a project: no stamp, no appendix.
        static let noProject = ProjectKey(stampName: nil, stampQuestion: nil, appendixProjectId: nil)

        /// A key of these values.
        init(stampName: String?, stampQuestion: String?, appendixProjectId: UUID?) {
            self.stampName = stampName
            self.stampQuestion = stampQuestion
            self.appendixProjectId = appendixProjectId
        }
    }

    /// The stored properties of `Collection` the page does not draw, by name, each with why.
    static let collectionPropertiesNotDrawn: [String: String] = [
        "documentEntries": "The entries are hashed one by one, from the list the editor passes in the outline's order.",
        "projectIds": "The projects that list the collection; the page names none of them. The project the stamp names is the active one, hashed as the project key.",
        "includeWordCloud": "The preview draws no word cloud: it is the export's alone (previewOptions()).",
        "createdAt": "Drawn nowhere.",
        "lastModified": "Stamped at a save, not at an edit, and drawn nowhere: every field it would stand for is hashed itself.",
    ]

    /// The stored properties of `CollectionEntry` the page does not draw, by name, each with why.
    static let entryPropertiesNotDrawn: [String: String] = [
        "collection": "The entry's collection, whose own fields are hashed as the collection's.",
        "collectionId": "The entry's collection's id; the editor passes that collection's entries alone.",
        "createdAt": "Drawn nowhere.",
        "lastModified": "Stamped at a save, not at an edit, and drawn nowhere: every field it would stand for is hashed itself.",
    ]

    /// One number for everything the page is drawn from, which moves when any of it does.
    ///
    /// - Parameters:
    ///   - collection: The collection, whose every stored property but those ``collectionPropertiesNotDrawn``
    ///     names is hashed.
    ///   - entries: Its entries, in the outline's order, each hashed in the same way.
    ///   - project: What the page names of the active project.
    ///   - documentCap: How many documents the page is rendered through; `nil` for every one.
    ///   - refreshToken: The preview's count of the changes it was told of (a download, a stored row).
    /// - Returns: The fingerprint, for `.task(id:)`.
    @MainActor
    static func fingerprint(collection: Collection, entries: [CollectionEntry], project: ProjectKey,
                            documentCap: Int?, refreshToken: Int) -> Int {
        var hasher = Hasher()
        // Which collection the page is, its title page, introduction, note and colophon (Phase 4).
        hasher.combine(collection.id)
        hasher.combine(collection.name)
        hasher.combine(collection.note)
        hasher.combine(collection.subtitle)
        hasher.combine(collection.authorLine)
        hasher.combine(collection.introductionText)
        hasher.combine(collection.introductionRichText)
        hasher.combine(collection.includeColophon)
        // The project stamp and the query log (#1997): their switches, and what they name.
        hasher.combine(collection.includeProjectProvenance)
        hasher.combine(collection.includeMethodAppendix)
        hasher.combine(project)
        hasher.combine(collection.savedSearchId)
        // The composition. The footnote pair is hashed as stored, with the legacy style it derives from.
        hasher.combine(collection.defaultBodyDepth)
        hasher.combine(collection.footnoteStyle)
        hasher.combine(collection.includeFootnotes)
        hasher.combine(collection.includeSourceNote)
        hasher.combine(collection.tocStyle)
        hasher.combine(collection.applyHighlights)
        hasher.combine(collection.includeNotes)
        hasher.combine(collection.defaultIncludeHeadnote)
        hasher.combine(collection.summaryPromptId)
        // The collection's own facts (L43): every citation's style, which line leads a document, the labels'
        // words, and the See also every document takes by default.
        hasher.combine(collection.citationStyle)
        hasher.combine(collection.opening)
        hasher.combine(collection.labelsJSON)
        hasher.combine(collection.defaultIncludeRelatedDocuments)
        for entry in entries {
            hasher.combine(entry.id)
            hasher.combine(entry.kind)
            hasher.combine(entry.documentId)
            hasher.combine(entry.volumeId)
            hasher.combine(entry.sortOrder)
            hasher.combine(entry.level)
            hasher.combine(entry.text)
            hasher.combine(entry.richText)
            // A document's heading and its contents row (#1997).
            hasher.combine(entry.titleOverride)
            hasher.combine(entry.bodyDepthOverride)
            hasher.combine(entry.selectedNoteIds)
            hasher.combine(entry.researchNoteId)
            hasher.combine(entry.includeHeadnote)
            hasher.combine(entry.headnoteSummaryId)
            // An excerpt prints its frozen passage (`text`); its anchors are hashed as they were since
            // Phase 5, so a rendering that reads them (A9) needs nothing here.
            hasher.combine(entry.excerptStart)
            hasher.combine(entry.excerptEnd)
            hasher.combine(entry.excerptRenderingVersion)
            hasher.combine(entry.excerptColorTag)
            hasher.combine(entry.applyHighlightsOverride)
            hasher.combine(entry.includeNotesOverride)
            hasher.combine(entry.includeSourceNoteOverride)
            hasher.combine(entry.includeFootnotesOverride)
            hasher.combine(entry.summaryPromptIdOverride)
            hasher.combine(entry.selectedHighlightIds)
            hasher.combine(entry.includeRelatedDocuments)
            hasher.combine(entry.generatedBlockType)
            // A document's date line under its title, and a section heading's Headnotes default (L43).
            hasher.combine(entry.dateLine)
            hasher.combine(entry.headnoteDefault)
        }
        hasher.combine(documentCap)
        hasher.combine(refreshToken)
        return hasher.finalize()
    }
}

// MARK: - Stored rows the preview draws (#1765)

/// The documents and notes whose stored rows a collection's preview draws without an entry holding
/// them: their summaries, highlights, notes and tag assignments (#1765).
struct CollectionPreviewUserDataScope: Hashable {

    /// A document, by its volume and its id within the volume.
    struct Document: Hashable {
        /// The volume identifier.
        let volumeId: String
        /// The document identifier within the volume.
        let documentId: String
    }

    /// Each document the preview resolves.
    let documents: Set<Document>

    /// The notes an entry names by id — a note entry, or a document's chosen notes — wherever they are
    /// attached.
    let noteIds: Set<UUID>

    /// No documents and no notes: a smart collection's scope before its first resolve.
    static let empty = CollectionPreviewUserDataScope(documents: [], noteIds: [])

    /// A scope of exactly these documents and notes.
    init(documents: Set<Document>, noteIds: Set<UUID>) {
        self.documents = documents
        self.noteIds = noteIds
    }

    /// A static collection's scope: its document entries, with the notes its entries name.
    init(entries: [CollectionEntry]) {
        var documents: Set<Document> = []
        var notes: Set<UUID> = []
        for entry in entries {
            if entry.entryKind == .document, !entry.volumeId.isEmpty {
                documents.insert(Document(volumeId: entry.volumeId, documentId: entry.documentId))
            }
            if let noteId = entry.researchNoteId { notes.insert(noteId) }
            notes.formUnion(entry.selectedNoteIds)
        }
        self.init(documents: documents, noteIds: notes)
    }

    /// A smart collection's scope: every document its saved search returned, the capped-out ones too,
    /// since the apparatus blocks read the whole result set.
    init(refs: [SmartCollectionDocumentRef]) {
        self.init(documents: Set(refs.map { Document(volumeId: $0.volumeId, documentId: $0.documentId) }),
                  noteIds: [])
    }

    /// Whether the document `volumeId`/`documentId` is in the scope.
    func covers(volumeId: String, documentId: String) -> Bool {
        documents.contains(Document(volumeId: volumeId, documentId: documentId))
    }

    /// The scope's volumes, for a query's predicate; with ``documentIds`` a superset of the scope,
    /// which ``digest(summaries:highlights:notes:assignments:tags:)`` narrows to it.
    var volumeIds: [String] { Array(Set(documents.map(\.volumeId))) }

    /// The scope's document ids, for a query's predicate (see ``volumeIds``).
    var documentIds: [String] { Array(Set(documents.map(\.documentId))) }

    /// One number for every stored row in the scope that the page draws, which moves when one of them
    /// is added, removed or edited, and not when a row outside the scope is (#1765).
    ///
    /// Each row is read by the fields the page draws, never by `lastModified` alone: a field's `didSet`
    /// that stamps it did not run in a test's model that no context holds, and the digest should not
    /// rest on it. Every user tag is read by name, for the Thematic Index. The rows are combined without
    /// regard to order, since a query gives them in none.
    func digest(summaries: [GeneratedSummary],
                highlights: [DocumentHighlight],
                notes: [ResearchNote],
                assignments: [DocumentTagAssignment],
                tags: [UserTag]) -> Int {
        var total = 0
        func add(_ build: (inout Hasher) -> Void) {
            var hasher = Hasher()
            build(&hasher)
            total &+= hasher.finalize()
        }
        for summary in summaries where covers(volumeId: summary.volumeId, documentId: summary.documentId) {
            add {
                $0.combine(0); $0.combine(summary.id); $0.combine(summary.responseText)
                $0.combine(summary.promptId); $0.combine(summary.isHeadnoteDraft)
                $0.combine(summary.authorship)
            }
        }
        for highlight in highlights where covers(volumeId: highlight.volumeId, documentId: highlight.documentId) {
            add {
                $0.combine(1); $0.combine(highlight.id)
                $0.combine(highlight.startOffset); $0.combine(highlight.endOffset)
                $0.combine(highlight.colorTag); $0.combine(highlight.noteId)
                $0.combine(highlight.renderingVersion)
            }
        }
        for note in notes
        where noteIds.contains(note.id) || covers(volumeId: note.volumeId, documentId: note.documentId) {
            add {
                $0.combine(2); $0.combine(note.id); $0.combine(note.bodyText); $0.combine(note.richText)
                $0.combine(note.userTagIds)
            }
        }
        for assignment in assignments
        where covers(volumeId: assignment.volumeId, documentId: assignment.documentId) {
            add { $0.combine(3); $0.combine(assignment.id); $0.combine(assignment.tagId) }
        }
        for tag in tags {
            add { $0.combine(4); $0.combine(tag.id); $0.combine(tag.name) }
        }
        return total
    }
}

/// What the user-data observer last reported, and whether a report is a change the page has not drawn
/// (#1765).
struct CollectionPreviewUserDataWatch: Equatable {

    /// The scope of the last report; `nil` before the first.
    private(set) var scope: CollectionPreviewUserDataScope?

    /// The digest of the last report.
    private(set) var digest: Int?

    /// Records `digest` over `scope`. `true` when it differs from the last report over the same scope —
    /// a row the page draws was stored, edited or removed — and `false` for the first report over a
    /// scope, which only sets the baseline: a scope moves when the entries or a smart collection's
    /// results do, and the resolve that follows reads the rows anyway.
    mutating func record(_ digest: Int, over scope: CollectionPreviewUserDataScope) -> Bool {
        defer {
            self.scope = scope
            self.digest = digest
        }
        return self.scope == scope && self.digest != digest
    }
}

/// Follows the stored rows a collection's preview draws without an entry holding them, and reports a
/// digest of them whenever one changes (#1765).
///
/// Mounted as the preview's background, so it lives exactly as long as the preview does, and live:
/// `@Query` follows the shared container, so a summary `SummarizationService` saves from a context of
/// its own, or a highlight made in another window, reaches it the moment it is stored — the pattern
/// Search's checklist observer set (#189-D), never a navigation or scene-phase edge. Each query is
/// limited to the scope's volumes and document ids, so a library's other summaries never run it.
private struct CollectionPreviewUserDataObserver: View {

    /// The documents and notes followed.
    let scope: CollectionPreviewUserDataScope

    /// Called with the scope and its digest when the observer appears and whenever the digest moves.
    let onReport: (CollectionPreviewUserDataScope, Int) -> Void

    @Query private var summaries: [GeneratedSummary]
    @Query private var highlights: [DocumentHighlight]
    @Query private var notes: [ResearchNote]
    @Query private var assignments: [DocumentTagAssignment]
    @Query private var tags: [UserTag]

    /// Builds the scoped queries.
    init(scope: CollectionPreviewUserDataScope,
         onReport: @escaping (CollectionPreviewUserDataScope, Int) -> Void) {
        self.scope = scope
        self.onReport = onReport
        let volumeIds = scope.volumeIds
        let documentIds = scope.documentIds
        let noteIds = Array(scope.noteIds)
        _summaries = Query(filter: #Predicate<GeneratedSummary> {
            volumeIds.contains($0.volumeId) && documentIds.contains($0.documentId)
        })
        _highlights = Query(filter: #Predicate<DocumentHighlight> {
            volumeIds.contains($0.volumeId) && documentIds.contains($0.documentId)
        })
        _notes = Query(filter: #Predicate<ResearchNote> {
            noteIds.contains($0.id) || (volumeIds.contains($0.volumeId) && documentIds.contains($0.documentId))
        })
        _assignments = Query(filter: #Predicate<DocumentTagAssignment> {
            volumeIds.contains($0.volumeId) && documentIds.contains($0.documentId)
        })
    }

    /// The digest of the rows the queries hold, narrowed to the scope.
    private var digest: Int {
        scope.digest(summaries: summaries, highlights: highlights, notes: notes,
                     assignments: assignments, tags: tags)
    }

    var body: some View {
        Color.clear
            .accessibilityHidden(true)
            .onAppear { onReport(scope, digest) }
            .onChange(of: digest) { _, newDigest in onReport(scope, newDigest) }
    }
}

// MARK: - CollectionPreviewWebView

/// Minimal per-platform `WKWebView` representable that displays a self-contained HTML
/// string (the shared renderer's `pageHTML` output), keeps the reader's place when a new page loads,
/// and brings a chosen row's document into view (L36).
///
/// Deliberately *not* built on `WKWebViewConfiguration.frusExplorerConfiguration`: that
/// factory exists to inject the offset-engine/highlight/selection scripts and the
/// `frusexplorer://` scheme handler for interactive single-document rendering, none of
/// which the export page uses. What it *does* share with `FRUSDocumentWebView` is the
/// navigation posture: the in-memory HTML load is allowed, in-page anchor jumps (the
/// ToC) are allowed, and activated external links open in the system browser instead of
/// navigating the preview away.
///
/// **What it adds of its own** (L36) is one script and one message handler. The script
/// (`placeScript`) reports where the reader stopped scrolling, and each page the web view
/// loads carries it at the end of its body with its landing: the chosen row's document when
/// the page holds it, else the reader's last place. The page itself is the export's, byte
/// for byte; the script is added at load, and an export never carries it.
struct CollectionPreviewWebView {

    /// The complete HTML page to display.
    let html: String

    /// The collection the page is, whose place `place` keeps.
    let collectionId: UUID

    /// The chosen row's document to bring into view, if any.
    let reveal: CollectionPreviewReveal?

    /// The editor's keeper of the reader's place.
    let place: CollectionPreviewPlace

    /// The message handler the page posts the reader's place to.
    static let placeMessage = "frusPreviewPlace"

    /// The page's place script: `FRUSPreviewPlace.read()` gives the reader's place (the document
    /// section holding the top of the view and how far into it the view begins, or the page's
    /// scroll above every document), `FRUSPreviewPlace.land(anchor, mark)` scrolls to `anchor`'s
    /// section and answers `true`, or, when the page has no such section, to `mark` and answers
    /// `false`; and 150 ms after the reader stops scrolling it posts the place to `placeMessage`.
    /// Its scrolls are instant, as the page sets no `scroll-behavior`.
    static let placeScript = """
    (function () {
      if (window.FRUSPreviewPlace) { return; }
      var place = {};
      place.top = function (element) { return element.getBoundingClientRect().top + window.scrollY; };
      place.read = function () {
        var sections = document.querySelectorAll('section[id^="doc-"]');
        var anchor = null, offset = 0;
        for (var i = 0; i < sections.length; i++) {
          var top = sections[i].getBoundingClientRect().top;
          if (top > 0.5) { break; }
          anchor = sections[i].id;
          offset = -top;
        }
        return { anchor: anchor, offset: offset, y: window.scrollY };
      };
      place.land = function (anchor, mark) {
        var target = anchor ? document.getElementById(anchor) : null;
        if (target) { window.scrollTo(0, Math.max(0, place.top(target))); return true; }
        if (mark) {
          var section = mark.anchor ? document.getElementById(mark.anchor) : null;
          window.scrollTo(0, Math.max(0, section ? place.top(section) + mark.offset : mark.y));
        }
        return false;
      };
      var timer = null;
      window.addEventListener('scroll', function () {
        if (timer !== null) { clearTimeout(timer); }
        timer = setTimeout(function () {
          timer = null;
          var handlers = window.webkit && window.webkit.messageHandlers;
          if (handlers && handlers.\(CollectionPreviewWebView.placeMessage)) { handlers.\(CollectionPreviewWebView.placeMessage).postMessage(place.read()); }
        }, 150);
      }, { passive: true });
      window.FRUSPreviewPlace = place;
    })();
    """

    /// A web view as the preview builds one, on either platform and in a test: a configuration of its
    /// own with `coordinator` as its place handler, and `coordinator` as its navigation and UI delegate.
    @MainActor
    static func makeWebView(coordinator: Coordinator) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: placeMessage)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        return webView
    }

    /// Shared navigation/UI delegate and place handler for both platform representables.
    ///
    /// Tracks the hash of the last-loaded HTML so SwiftUI update passes that didn't
    /// change the page never reload it, and routes external links (including
    /// `target="_blank"` ones, via the `createWebViewWith` UI-delegate hook) to the
    /// system browser. Since L36 it lands each page it loads (`show(_:collectionId:reveal:in:)`),
    /// records the place the page reports, and brings a chosen row's document into view, now when
    /// the page holds it and at the next load when it does not yet.
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

        /// The editor's keeper of the reader's place, which the page reports to and each load lands on.
        let place: CollectionPreviewPlace

        /// The collection the page shown is.
        private var collectionId: UUID?

        /// Hash of the most recently loaded HTML string; suppresses no-op reloads.
        private var lastHTMLHash: Int?

        /// The load under way, which alone ends `isLoading` and lands: a load the next one cancels does not.
        private var navigation: WKNavigation?

        /// `true` from a load's start to its end.
        private var isLoading = false

        /// Where the page being loaded lands: a chosen row's document, or the reader's place as it was
        /// when the load began.
        private var landing: (anchor: String?, mark: CollectionPreviewPlace.Mark?)?

        /// A chosen row's document not yet brought into view.
        private var pendingReveal: CollectionPreviewReveal?

        /// The choice looked for on the page shown, which did not hold its document: looked for again
        /// at the next load, not at every update.
        private var revealMissedOnPage: Int?

        /// How many landings have run, each at a load's end or for a choice: what a test waits on.
        private(set) var landings = 0

        /// A coordinator that keeps the reader's place in `place`.
        init(place: CollectionPreviewPlace) {
            self.place = place
            super.init()
        }

        /// Shows `html`, `collectionId`'s page: loads it when it is not the page shown, landing on the
        /// chosen row's document or the reader's place, and otherwise brings a new choice's document
        /// into view. A choice whose document the page shown lacks waits for the next load.
        func show(_ html: String, collectionId: UUID, reveal: CollectionPreviewReveal?, in webView: WKWebView) {
            self.collectionId = collectionId
            pendingReveal = reveal.flatMap { $0.serial == place.revealedSerial ? nil : $0 }
            let hash = html.hashValue
            if hash != lastHTMLHash {
                lastHTMLHash = hash
                let landing = (anchor: pendingReveal?.anchor, mark: place.mark(in: collectionId))
                self.landing = landing
                isLoading = true
                revealMissedOnPage = nil
                navigation = webView.loadHTMLString(Self.page(html, landing: landing), baseURL: nil)
            } else if !isLoading, let pending = pendingReveal, pending.serial != revealMissedOnPage {
                land(anchor: pending.anchor, mark: nil, in: webView)
            }
        }

        /// `html` with the place script and its landing at the end of its body, where they run once the
        /// page is parsed, before it is first drawn, so a page lands without showing its top first.
        static func page(_ html: String, landing: (anchor: String?, mark: CollectionPreviewPlace.Mark?)) -> String {
            let script = "<script>\n\(CollectionPreviewWebView.placeScript)\n"
                + "\(landingCall(anchor: landing.anchor, mark: landing.mark));\n</script>\n"
            guard let end = html.range(of: "</body>", options: .backwards) else { return html + script }
            var page = html
            page.insert(contentsOf: script, at: end.lowerBound)
            return page
        }

        /// The script that lands the page on `anchor`'s section, answering `true`, or on `mark` when the
        /// page has no such section, answering `false`.
        static func landingCall(anchor: String?, mark: CollectionPreviewPlace.Mark?) -> String {
            "FRUSPreviewPlace.land(\(json(anchor)), \(json(mark)))"
        }

        /// `value` as a JavaScript literal, `null` when absent.
        private static func json<Value: Encodable>(_ value: Value?) -> String {
            guard let value, let data = try? JSONEncoder().encode(value) else { return "null" }
            return String(decoding: data, as: UTF8.self)
        }

        /// Lands the page shown again on `anchor`, else `mark`, and records whether a pending choice's
        /// document was brought into view.
        private func land(anchor: String?, mark: CollectionPreviewPlace.Mark?, in webView: WKWebView) {
            let serial = pendingReveal?.serial
            let script = Self.landingCall(anchor: anchor, mark: mark)
            Task { @MainActor [weak self, weak webView] in
                guard let webView else { return }
                let revealed = (try? await webView.evaluateJavaScript(script)) as? Bool
                guard let self else { return }
                landings += 1
                guard let serial else { return }
                if revealed == true {
                    place.revealedSerial = serial
                    if pendingReveal?.serial == serial { pendingReveal = nil }
                } else {
                    revealMissedOnPage = serial
                }
            }
        }

        /// Lands the loaded page again, now that it is whole: its images may have moved what the
        /// landing at the end of its body scrolled to.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard navigation === self.navigation else { return }
            isLoading = false
            land(anchor: pendingReveal?.anchor ?? landing?.anchor, mark: landing?.mark, in: webView)
        }

        /// Ends the load under way when it fails, so a later choice is brought into view on the page shown.
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            if navigation === self.navigation { isLoading = false }
        }

        /// Ends the load under way when it fails before it commits.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: any Error) {
            if navigation === self.navigation { isLoading = false }
        }

        /// Records the place the page reports as the reader's on the collection shown.
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == CollectionPreviewWebView.placeMessage, let collectionId,
                  let mark = CollectionPreviewPlace.Mark(messageBody: message.body) else { return }
            place.record(mark, in: collectionId)
        }

        /// Allows the `loadHTMLString` load and in-page anchor navigation; cancels
        /// activated http(s) link taps and opens them externally instead.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            if navigationAction.navigationType == .linkActivated,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                Self.openExternally(url)
                return .cancel
            }
            return .allow
        }

        /// `target="_blank"` links request a new web view; open them in the system
        /// browser and create no child web view.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                Self.openExternally(url)
            }
            return nil
        }

        /// Opens a URL in the platform's default browser.
        private static func openExternally(_ url: URL) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}

#if os(macOS)

extension CollectionPreviewWebView: NSViewRepresentable {

    /// Creates the macOS web view with the shared coordinator as its delegates.
    func makeNSView(context: Context) -> WKWebView {
        let webView = Self.makeWebView(coordinator: context.coordinator)
        webView.autoresizingMask = [.width, .height]
        return webView
    }

    /// Shows the page, loading it when the HTML content changed.
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.show(html, collectionId: collectionId, reveal: reveal, in: webView)
    }

    /// Lets go of the place handler, which the web view's configuration holds.
    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: placeMessage)
    }

    /// Creates the shared navigation/UI delegate.
    func makeCoordinator() -> Coordinator { Coordinator(place: place) }
}

#else

extension CollectionPreviewWebView: UIViewRepresentable {

    /// Creates the iOS web view with the shared coordinator as its delegates.
    func makeUIView(context: Context) -> WKWebView {
        Self.makeWebView(coordinator: context.coordinator)
    }

    /// Shows the page, loading it when the HTML content changed.
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.show(html, collectionId: collectionId, reveal: reveal, in: webView)
    }

    /// Lets go of the place handler, which the web view's configuration holds.
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: placeMessage)
    }

    /// Creates the shared navigation/UI delegate.
    func makeCoordinator() -> Coordinator { Coordinator(place: place) }
}

#endif
