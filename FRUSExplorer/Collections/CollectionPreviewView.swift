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
/// Re-resolution is keyed on a `Hashable` fingerprint of the entries (ids, kind, text,
/// rich text, overrides, note selections, sort order) plus the collection's composition
/// fields, via `.task(id:)`. Edits settle for ~1 second before a re-resolve runs; the
/// first render and explicit user actions (Render All, download completion) skip the
/// debounce. A superseded resolve is cancelled by SwiftUI and discards its result.
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
/// browser (same navigation-delegate posture as `FRUSDocumentWebView`).
///
/// Scroll-sync and per-item incremental DOM patching are explicitly out of scope here
/// (optional Phase 2c); full-page debounced regeneration is the contract of this PR.
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

    // MARK: - Fingerprint

    /// Hash of everything the rendered page depends on: per-entry identity and content
    /// (id, kind, document/volume ids, sort order, text, rich text, body-depth override,
    /// note selections) plus the collection's composition fields. Reading these
    /// observable properties during body evaluation also registers the SwiftUI
    /// dependencies that re-run the `.task` when they change.
    private var contentFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(collection.name)
        hasher.combine(collection.note)
        hasher.combine(collection.savedSearchId)
        hasher.combine(collection.defaultBodyDepth)
        hasher.combine(collection.footnoteStyle)
        // Phase 5 footnote pair — the effective values also cover legacy derivation.
        hasher.combine(collection.includeFootnotes)
        hasher.combine(collection.includeSourceNote)
        hasher.combine(collection.tocStyle)
        hasher.combine(collection.applyHighlights)
        hasher.combine(collection.includeNotes)
        hasher.combine(collection.summaryPromptId)
        // Phase 4 publication frame: title page, introduction, colophon, heading levels.
        hasher.combine(collection.subtitle)
        hasher.combine(collection.authorLine)
        hasher.combine(collection.introductionText)
        hasher.combine(collection.introductionRichText)
        hasher.combine(collection.includeColophon)
        for entry in entries {
            hasher.combine(entry.id)
            hasher.combine(entry.kind)
            hasher.combine(entry.documentId)
            hasher.combine(entry.volumeId)
            hasher.combine(entry.sortOrder)
            hasher.combine(entry.text)
            hasher.combine(entry.richText)
            hasher.combine(entry.level)
            hasher.combine(entry.bodyDepthOverride)
            hasher.combine(entry.selectedNoteIds)
            hasher.combine(entry.researchNoteId)
            // Phase 5 headnote fields — toggling them live-refreshes the preview.
            hasher.combine(entry.includeHeadnote)
            hasher.combine(entry.headnoteSummaryId)
            // Phase 5 excerpt anchors — a re-anchored or re-coloured excerpt refreshes
            // (the passage itself is `text`, already hashed above).
            hasher.combine(entry.excerptStart)
            hasher.combine(entry.excerptEnd)
            hasher.combine(entry.excerptRenderingVersion)
            hasher.combine(entry.excerptColorTag)
            // Phase 5 per-entry overrides — toggling any inspector override refreshes.
            hasher.combine(entry.applyHighlightsOverride)
            hasher.combine(entry.includeNotesOverride)
            hasher.combine(entry.includeSourceNoteOverride)
            hasher.combine(entry.includeFootnotesOverride)
            hasher.combine(entry.summaryPromptIdOverride)
            hasher.combine(entry.selectedHighlightIds)
            hasher.combine(entry.includeRelatedDocuments)
            // Phase 6 generated blocks — adding/retyping an apparatus block refreshes.
            hasher.combine(entry.generatedBlockType)
        }
        hasher.combine(renderAll)
        hasher.combine(refreshToken)
        return hasher.finalize()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !missingVolumeIds.isEmpty {
                missingVolumesBar
                Divider()
            }
            if !renderAll && totalDocumentCount > Self.initialDocumentCap {
                capBar
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
        // Whenever volumes are missing, poll until they arrive — via the preview's own
        // Download button OR any other path (the editor's Export, the Browser) — then
        // force a refresh so the citation cards never go stale. Keyed on the missing
        // set; `.task`-scoped, so it cancels with the pane.
        .task(id: missingVolumeIds) {
            await pollForVolumeArrivals()
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
                CollectionPreviewWebView(html: html)
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

    /// Bar shown when the collection exceeds the initial document cap, with the
    /// Render All button that lifts it for the editor session. The "of M" total is the
    /// true document count — for smart collections, the full search-result count, even
    /// though only the capped prefix was resolved.
    private var capBar: some View {
        HStack(spacing: 12) {
            Text(String(localized: "collection.preview.capNotice",
                        defaultValue: "Showing first \(Self.initialDocumentCap) of \(totalDocumentCount) documents"))
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
        do {
            let items: [CollectionExportItem]
            if isSmart {
                // Smart path: fetch the lightweight search-result refs (an FTS5 query —
                // no parsing), cap them BEFORE per-document resolution so at most the
                // cap is ever parsed, and keep the true total for the cap bar.
                let refs = try await resolver.smartRefs(for: collection)
                let docCount = refs.count
                let cappedRefs = (renderAll || docCount <= Self.initialDocumentCap)
                    ? refs
                    : Array(refs.prefix(Self.initialDocumentCap))
                let resolved = try await resolver.resolve(
                    smartRefs: cappedRefs, collection: collection, allNotes: allNotes,
                    purpose: .preview, fullRefs: refs)
                if Task.isCancelled { return }
                totalDocumentCount = docCount
                items = resolved
            } else {
                // Static path: cap the entries *before* resolution so the parse cost of
                // documents past the cap is never paid.
                let docCount = entries.filter { $0.entryKind == .document }.count
                let cappedEntries = (renderAll || docCount <= Self.initialDocumentCap)
                    ? entries
                    : Self.capEntries(entries, cap: Self.initialDocumentCap)
                let resolved = try await resolver.resolve(
                    collection: collection, entries: cappedEntries, allNotes: allNotes,
                    purpose: .preview)
                if Task.isCancelled { return }
                totalDocumentCount = docCount
                items = resolved
            }

            var renderer = CollectionItemHTMLRenderer(options: previewOptions())
            renderer.citationOnlyVolumeIds = missing
            renderer.showsSummaryPlaceholders = true
            let provenance = CollectionExportMetadata.projectProvenance(
                enabled: collection.includeProjectProvenance,
                projectName: activeProject?.name,
                researchQuestion: activeProject?.researchQuestion)
            let appendixLines = ResearchDataExporter.collectionMethodAppendixLines(
                enabled: collection.includeMethodAppendix,
                modelContext: modelContext,
                activeProject: activeProject)
            let metadata = CollectionExportMetadata(
                name: collection.name.isEmpty
                    ? String(localized: "collection.editor.untitled",
                             defaultValue: "Untitled Collection")
                    : collection.name,
                note: collection.note,
                subtitle: collection.subtitle,
                authorLine: collection.authorLine,
                projectName: provenance.name,
                projectResearchQuestion: provenance.question,
                includeColophon: collection.includeColophon,
                methodAppendixLines: appendixLines)
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

    /// Preview rendering options mirroring the export sheet's `buildExportOptions`,
    /// minus the format-dependent word cloud (export-only decoration).
    private func previewOptions() -> CollectionExportOptions {
        CollectionExportOptions(
            tocStyle:          CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            includeFootnotes:  collection.effectiveIncludeFootnotes,
            includeSourceNote: collection.effectiveIncludeSourceNote,
            applyHighlights:   collection.applyHighlights,
            includeNotes:      collection.includeNotes,
            summaryPromptId:   collection.summaryPromptId,
            includeWordCloud: false
        )
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
            guard let entry = manifest.first(where: { $0.volumeId == volumeId }) else { continue }
            enqueuedAny = true
            Task { await dm.enqueueDownload(volumeId: entry.volumeId,
                                            downloadUrl: entry.downloadUrl) }
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

// MARK: - CollectionPreviewWebView

/// Minimal per-platform `WKWebView` representable that displays a self-contained HTML
/// string (the shared renderer's `pageHTML` output).
///
/// Deliberately *not* built on `WKWebViewConfiguration.frusExplorerConfiguration`: that
/// factory exists to inject the offset-engine/highlight/selection scripts and the
/// `frusexplorer://` scheme handler for interactive single-document rendering, none of
/// which the export page uses. What it *does* share with `FRUSDocumentWebView` is the
/// navigation posture: the in-memory HTML load is allowed, in-page anchor jumps (the
/// ToC) are allowed, and activated external links open in the system browser instead of
/// navigating the preview away.
private struct CollectionPreviewWebView {

    /// The complete HTML page to display.
    let html: String

    /// Shared navigation/UI delegate for both platform representables.
    ///
    /// Tracks the hash of the last-loaded HTML so SwiftUI update passes that didn't
    /// change the page never reload it, and routes external links (including
    /// `target="_blank"` ones, via the `createWebViewWith` UI-delegate hook) to the
    /// system browser.
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, @unchecked Sendable {

        /// Hash of the most recently loaded HTML string; suppresses no-op reloads.
        var lastHTMLHash: Int?

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
        @MainActor
        private static func openExternally(_ url: URL) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }

    /// Loads `html` into the web view when it differs from the last-loaded page.
    @MainActor
    private func loadIfNeeded(into webView: WKWebView, coordinator: Coordinator) {
        let hash = html.hashValue
        guard coordinator.lastHTMLHash != hash else { return }
        coordinator.lastHTMLHash = hash
        webView.loadHTMLString(html, baseURL: nil)
    }
}

#if os(macOS)

extension CollectionPreviewWebView: NSViewRepresentable {

    /// Creates the macOS web view with the shared coordinator as its delegates.
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.autoresizingMask = [.width, .height]
        return webView
    }

    /// Reloads the page when the HTML content changed.
    func updateNSView(_ webView: WKWebView, context: Context) {
        loadIfNeeded(into: webView, coordinator: context.coordinator)
    }

    /// Creates the shared navigation/UI delegate.
    func makeCoordinator() -> Coordinator { Coordinator() }
}

#else

extension CollectionPreviewWebView: UIViewRepresentable {

    /// Creates the iOS web view with the shared coordinator as its delegates.
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    /// Reloads the page when the HTML content changed.
    func updateUIView(_ webView: WKWebView, context: Context) {
        loadIfNeeded(into: webView, coordinator: context.coordinator)
    }

    /// Creates the shared navigation/UI delegate.
    func makeCoordinator() -> Coordinator { Coordinator() }
}

#endif
