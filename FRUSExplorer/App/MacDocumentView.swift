// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import SwiftData
import WebKit

/// Displays a single FRUS document in the main macOS window.
///
/// ## Content Regions (top to bottom)
/// 1. Document identity line (doc number, volume ID, editorial note badge)
/// 2. Document body rendered by `FRUSDocumentRenderer` (macOS node-based renderer)
/// 3. Inline AI summary block (Apple Intelligence, collapsible)
/// 4. Footnote section (numbered, rendered by `FootnoteSectionView`)
/// 5. Tag row (system subject tags + user tags)
/// 6. Volume navigation (prev / next document in volume)
///
/// ## Navigation
/// Prev/next navigation appends to `navigationPath` (owned by `MainWindowView`) so
/// the back button history is preserved. Cross-reference link taps append to the same
/// path — navigation inside a host stays local to the host's own stack.
///
/// ## Session 68c Note
/// The new macOS architecture uses `NavigationStack` (not `NavigationSplitView`), so
/// each navigation push creates a fresh view instance with fresh `@State`. The
/// `task(id:)` pattern from Session 68c is not needed here — `loadDocument()` is
/// called once per view lifetime via a plain `.task {}`.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; replaces BrowserView-centric architecture)
///   1.1 — Session 91: removed private EditorialNoteBadge and TagChip; now uses
///          shared FRUSTheme components (EditorialNoteBadge, FRUSTagChip)
///   1.2 — Session 100: logEvent(.documentOpen) in .task (removed in Wave R-2a: the visit
///          is already recorded as a `ReadingHistoryEntry` by `loadDocument()`, and the
///          `SessionEvent` store it wrote to is retired)
///   1.3 — Session 103: highlight mode toggle + DocumentHighlightTextView +
///          color-picker popover + DocumentHighlight SwiftData insertion
///   1.4 — Session 105: renderingVersion uses SHA-256(flatText ++ kVersion) via
///          ASTToRenderNodeConverter.renderingVersion(for:)
///   1.5 — Session 106: @Query for stored highlights; overlay rendering; stale warning banner;
///          note anchoring
///   1.6 — Highlight controls + Sources moved out of this view; state managed via
///          HighlightCoordinator passed from MainWindowView (the host was the
///          research strip, retired in the rail redesign)
///   1.7 — Session 154: applies the default document mode preference
///          (Read/Research/remember-last) to `panelVisible` once per document open
///   1.8 — Authoring Phase 5 (excerpts): publishes the loaded document's rendering
///          version to `HighlightCoordinator.currentRenderingVersion` so selection
///          excerpt captures carry it (decision A9 anchors)
///   1.9 — Authoring Phase 5 review fixes: excerpt captures built here (owns the
///          render model) via `makeExcerptCaptureAction`, re-extracting the passage
///          block-aware with `flatTextExcerpt` so the frozen text matches its anchors;
///          highlight `selectedText` gains paragraph breaks the same way;
///          `currentRenderingVersion` superseded and removed
///   2.0 — Session 2026-07-03 (people-eval finding G): PersonDetailSheet's "Find all
///          mentions" searches the resolved rollup identity (matching the displayed
///          cross-corpus count) instead of the cross-volume-colliding raw `personRef`
///   2.1 — Session 2026-07-04 (macOS UI audit C1): research-panel note rows and
///          "Add Note" open the frus.noteComposer window (`openNoteComposer`,
///          pendingNoteComposer hand-off) instead of `ResearchNoteEditorView`
///          sheets — the document stays readable while composing
///   2.2 — Session 2026-07-04 (macOS UI audit gap 6): publishes
///          `DocumentCommandActions` as the `\.documentCommands` focused-scene
///          value, wiring the "Document" menu's reading shortcuts (⌥⌘↑/⌥⌘↓
///          prev/next, ⌘⇧N add note, ⌘⇧H highlight selection, ⌘⇧R research
///          panel) to this view's existing actions in whichever window is key
///   2.3 — Session 7 / #240B: `onBrokenRefTap` presents `BrokenRefExplanationSheet`
///          for cross-references the broken-refs index degrades
@MainActor
struct MacDocumentView: View {

    let entry: DocumentBrowserEntry
    @Binding var navigationPath: [DocumentBrowserEntry]
    let highlightCoordinator: HighlightCoordinator

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// Opens external (non-FRUS) cross-reference URLs in the system browser.
    @Environment(\.openURL) private var openURL
    /// Opens the research-note composer window (UI audit C1).
    @Environment(\.openWindow) private var openWindow
    /// The identity of the document host this view is mounted in (set at each host root —
    /// `MainWindowView` or `MacDocumentWindowView`). Tool launchers here (Find all mentions)
    /// stamp it as the spawned tool's provenance, so the tool's opens route back to THIS window.
    @Environment(\.documentHostID) private var documentHostID

    @State private var vm: DocumentViewModel
    @State private var prevEntry: DocumentBrowserEntry? = nil
    @State private var nextEntry: DocumentBrowserEntry? = nil
    /// Which edge chevron is hover-revealed in Read mode (C2.4); `nil` = neither.
    @State private var hoveredNavEdge: NavEdge? = nil
    @State private var showPersonNotFound = false
    @State private var showGlossNotFound  = false
    /// Set when an unresolvable cross-reference is tapped; drives the explanation sheet (#240).
    @State private var brokenRefExplanation: BrokenRefInfo? = nil
    /// Presents the per-document review of a volume update's change set (R-5 P3).
    @State private var showReviewChanges = false
    /// Set when a cross-reference targets a document in an undownloaded volume; drives
    /// a prompt offering to download it instead of pushing into a guaranteed load failure.
    @State private var crossRefDownloadVolumeId: String? = nil

    /// The footnote to reveal in the rendered document (#988) — seeded from `entry.footnoteAnchor`
    /// on load, and re-set in place for a reference naming a note in this same document.
    @State private var revealedFootnoteAnchor: String? = nil
    /// Offsets of the highlight the user tapped; drives the delete-confirmation alert.
    @State private var highlightToDelete: (Int, Int)? = nil
    /// Visibility + anchor for the floating selection bar (Research-rail Phase B2). Driven straight
    /// from the selection payload's rect. macOS `NavigationStack` gives each *pushed* document a
    /// fresh view instance (see the type doc), so no cross-document offset leak is possible. But a
    /// pushed instance is RETAINED for pop-back, so the bar is explicitly dismissed on
    /// `.onDisappear` to avoid a stale "zombie" bar re-appearing when the user navigates back.
    @State private var selectionBar = SelectionBarState()

    /// Find-in-document controller (#363 #5) — owns the find bar's query/visibility and the
    /// live web view for `WKWebView.find`. One per document surface (main window + each
    /// standalone document window), so each searches its own document.
    @State private var findController = DocumentFindController()
    /// Excerpt capture pending presentation in the bar's Excerpt flow (unified with the
    /// research rail's picker state in C1).
    @State private var pendingExcerptCapture: CollectionExcerptCapture? = nil
    /// Presents the collection picker in excerpt mode for `pendingExcerptCapture`.
    @State private var showAddExcerpt = false

    @Query private var highlights:              [DocumentHighlight]
    /// This document's `document_revisions` row (R-5 P2), loaded per open; nil until read or when
    /// the volume has never been re-indexed. Feeds `DocumentChangeBanner` beside the highlight check.
    @State private var revision: IndexingPipeline.DocumentRevision?

    // Research rail visibility (⌘⇧R) — gates the trailing rail + the volume-nav bar (C5). The
    // rail owns the per-accordion expansion keys; this view only needs the top-level toggle.
    @AppStorage("frus.document.researchPanel.visible")   private var panelVisible    = true
    /// Which mode (Read/Research/remember-last) a document opens in (Session 154).
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast

    // MARK: - Init

    init(entry: DocumentBrowserEntry,
         navigationPath: Binding<[DocumentBrowserEntry]>,
         highlightCoordinator: HighlightCoordinator) {
        self.entry = entry
        self._navigationPath = navigationPath
        self.highlightCoordinator = highlightCoordinator
        // DocumentViewModel constructed here; services injected in .task below
        // because @Environment is not accessible at init time.
        self._vm = State(initialValue: DocumentViewModel(
            entry: entry,
            volumeEntry: nil,
            parser: FRUSDocumentParser()
        ))
        let vId = entry.volumeId
        let dId = entry.documentId
        self._highlights = Query(
            filter: #Predicate<DocumentHighlight> { h in
                h.volumeId == vId && h.documentId == dId
            },
            sort: \DocumentHighlight.createdAt
        )
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let renderModel = vm.renderModel {
                webKitDocumentView(renderModel: renderModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.isLoading {
                ProgressView()
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else if let error = vm.loadError {
                if let dm = appState.downloadManager, !dm.isVolumeDownloaded(entry.volumeId) {
                    // The load failed because the volume isn't downloaded (e.g. reached
                    // via history re-open or a deep link). Offer download rather than a
                    // bare error, so this is never a dead end.
                    ContentUnavailableView {
                        Label(String(localized: "document.notDownloaded.title",
                                     defaultValue: "Volume Not Downloaded"),
                              systemImage: "arrow.down.circle")
                    } description: {
                        Text(String(localized: "document.notDownloaded.detail",
                                    defaultValue: "This document is in a volume you haven’t downloaded yet."))
                    } actions: {
                        Button(String(localized: "document.notDownloaded.download",
                                      defaultValue: "Download Volume")) {
                            if let manifestEntry = appState.manifestStore.entry(forVolumeId: entry.volumeId) {
                                Task { await dm.enqueueDownload(manifestEntry) }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 40)
                } else {
                    ContentUnavailableView(
                        "Could not load document",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                    .padding(.top, 40)
                }
            } else {
                // Pre-load state: .task hasn't fired yet, or downloadManager wasn't
                // ready. Never show a blank view — show a spinner so the user sees
                // the document area is active.
                ProgressView()
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            // Apply the default document mode on open. .rememberLast leaves panelVisible untouched,
            // preserving the prior cross-document persistence; .read/.research force it (⌘⇧R or the
            // D6 toolbar toggle can switch live afterwards). Guarded to write only when the value
            // actually changes (plan §7 C1 rider) — the key is shared across windows, so an
            // unconditional same-value write fires spurious cross-window rail refreshes.
            switch defaultDocumentMode {
            case .read:         if panelVisible { panelVisible = false }
            case .research:     if !panelVisible { panelVisible = true }
            case .rememberLast: break
            }
            await loadDocument()
            // R-5 P2: this document's recorded change, if an update stamped one.
            revision = await DocumentChangeBanner.revision(volumeId: entry.volumeId,
                                                           documentId: entry.documentId,
                                                           pipeline: appState.indexingPipeline)
            // #988: the note this navigation was aimed at, if any. macOS mounts a fresh
            // MacDocumentView per push, so this runs once per document.
            revealedFootnoteAnchor = entry.footnoteAnchor
            highlightCoordinator.createWebKitHighlightAction = createWebKitHighlight(color:)
            // Excerpt captures (Authoring Phase 5) are built here — this view owns
            // vm.renderModel, so the passage is re-extracted from the flat text with
            // its anchors instead of freezing the raw selection string.
            highlightCoordinator.makeExcerptCaptureAction = makeSelectionExcerptCapture
            // Wave R-2a: the `appState.logEvent(.documentOpen(…))` that used to sit here is gone —
            // `loadDocument()` above already records the visit via
            // `DocumentViewModel.recordReadingHistory`, and that is the trail now.
        }
        .userActivity(AppActivityTypes.document, element: entry) { entry, activity in
            activity.title = entry.header.isEmpty ? entry.documentId : entry.header
            activity.userInfo = ["volumeId": entry.volumeId, "documentId": entry.documentId]
            activity.isEligibleForHandoff = true
        }
        // "Document" menu wiring (UI audit gap 6): publish this document's reading
        // actions to the menu bar for as long as this view's scene is key. Reading
        // the coordinator's selection range here also makes body observe it, so the
        // menu's "Highlight Selection" enablement tracks live selection changes.
        // Optional-typed so the Equatable focusedSceneValue overload is selected
        // (the non-optional variant is deprecated on macOS 15).
        .focusedSceneValue(\.documentCommands, documentCommands)
        .sheet(item: $vm.selectedPerson) { person in
            PersonDetailSheet(
                person: person,
                mentionCount: vm.selectedPersonMentionCount,
                onFindAllMentions: {
                    // Search the resolved cross-corpus rollup identity — the same identity whose
                    // count the sheet displays; the raw per-volume `ref` collides across volumes
                    // and is only the fallback when the rollup isn't built (people-eval finding
                    // G). The Search window is opened DIRECTLY (the MainWindowView relay is
                    // retired — provenance PR 2, so this works from a standalone document
                    // window with the main window closed) and bound to THIS host, so result
                    // clicks come back to the window the user was reading in.
                    if let rollupId = vm.selectedPersonRollupId {
                        appState.openSearch(SearchParameters(personRollupId: rollupId,
                                                                  personLabel: person.name), from: nil)
                    } else {
                        appState.openSearch(SearchParameters(personRef: person.ref,
                                                                  personLabel: person.name), from: nil)
                    }
                    appState.bindTool(.search, to: documentHostID)
                    openWindow.fronting(id: "frus.search")
                }
            )
        }
        .sheet(item: $vm.selectedGloss) { gloss in
            GlossDetailSheet(gloss: gloss)
        }
        .sheet(item: $brokenRefExplanation) { info in
            BrokenRefExplanationSheet(info: info)
        }
        .sheet(isPresented: $showReviewChanges) {
            DocumentChangeReviewSheet(volumeId: entry.volumeId, documentId: entry.documentId,
                                      title: entry.header,
                                      currentVersion: vm.renderModel.map { ASTToRenderNodeConverter.renderingVersion(for: $0) })
        }
        // R-5 P3b-7: a Summarize Again that failed AFTER its sheet was dismissed. Success already
        // reaches this document through `revisionReviewToken`; this is the other half, routed onto
        // the same `summarizationError` surface the document's own Regenerate uses, and claimed
        // only by the document it names.
        .onChange(of: appState.summarizeAgainFailure) { _, failure in
            guard let failure,
                  failure.volumeId == entry.volumeId,
                  failure.documentId == entry.documentId else { return }
            vm.summarizationError = failure.message
            appState.summarizeAgainFailure = nil
        }
        // R-5 P3: a review write anywhere (this sheet, Research, the hub) re-reads the row.
        .onChange(of: appState.revisionReviewToken) { _, _ in
            // R-5 P3b-7: the carousel is a snapshot ARRAY, not a `@Query`, so a summary made from
            // the review sheet is invisible until something reloads it. Without this the reader
            // presses Summarize Again, closes the sheet, and finds the same summaries as before.
            // Position-preserving because this token fires on every review write, and a plain
            // `loadSummaries` sends the reader back to summary 1 when they mark a change reviewed.
            vm.reloadSummariesPreservingSelection(context: modelContext)
            Task {
                revision = await DocumentChangeBanner.revision(volumeId: entry.volumeId,
                                                               documentId: entry.documentId,
                                                               pipeline: appState.indexingPipeline)
            }
        }
        .alert(
            String(localized: "personNotFound.title",
                   defaultValue: "Person Information Unavailable"),
            isPresented: $showPersonNotFound
        ) {
            Button(String(localized: "personNotFound.dismiss", defaultValue: "OK")) {}
        } message: {
            Text(String(localized: "personNotFound.detail.v2",
                        defaultValue: "This volume was indexed before the app recorded details about people. To add them, re-index the volume in Settings → Volumes & Storage."))
        }
        .alert(
            String(localized: "glossNotFound.title",
                   defaultValue: "Term Definition Unavailable"),
            isPresented: $showGlossNotFound
        ) {
            Button(String(localized: "glossNotFound.dismiss", defaultValue: "OK")) {}
        } message: {
            Text(String(localized: "glossNotFound.detail.v2",
                        defaultValue: "This volume was indexed before the app recorded definitions. To add them, re-index the volume in Settings → Volumes & Storage."))
        }
        .alert(
            String(localized: "document.crossref.download.title",
                   defaultValue: "Volume Not Downloaded"),
            isPresented: Binding(
                get:  { crossRefDownloadVolumeId != nil },
                set:  { if !$0 { crossRefDownloadVolumeId = nil } }
            ),
            presenting: crossRefDownloadVolumeId
        ) { volumeId in
            Button(String(localized: "document.crossref.download.confirm",
                          defaultValue: "Download Volume")) {
                if let dm = appState.downloadManager,
                   let entry = appState.manifestStore.entry(forVolumeId: volumeId) {
                    Task { await dm.enqueueDownload(entry) }
                }
                crossRefDownloadVolumeId = nil
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                crossRefDownloadVolumeId = nil
            }
        } message: { volumeId in
            let title = appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
            Text(String(format: String(localized: "document.crossref.download.message %@",
                                        defaultValue: "The linked document is in “%@”, which isn’t downloaded yet. Download it to open the document."),
                        title))
        }
        .alert(
            String(localized: "highlight.delete.title",
                   defaultValue: "Remove Highlight"),
            isPresented: Binding(
                get:  { highlightToDelete != nil },
                set:  { if !$0 { highlightToDelete = nil } }
            )
        ) {
            Button(
                String(localized: "highlight.delete.confirm", defaultValue: "Remove"),
                role: .destructive
            ) {
                if let (start, end) = highlightToDelete {
                    deleteHighlight(startOffset: start, endOffset: end)
                }
                highlightToDelete = nil
            }
            Button(String(localized: "highlight.delete.cancel", defaultValue: "Cancel"),
                   role: .cancel) {
                highlightToDelete = nil
            }
        } message: {
            Text(String(localized: "highlight.delete.message",
                        defaultValue: "This highlight will be permanently removed."))
        }
    }

    // MARK: - WebKit document view (Session 142+)

    /// Below this container width the Research rail becomes a trailing OVERLAY instead of a
    /// side-by-side panel, so the reading column never reflows below its ~340 pt floor
    /// (640 pt window min − 300 pt rail = 340). Above it the rail sits side-by-side (C2.3).
    private static let railOverlayBreakpoint: CGFloat = 900

    /// Document view for the WebKit rendering path.
    ///
    /// `WKWebView` handles all scrolling, typography, and footnote display (HTML Popover API). The
    /// document identity line and highlights banner are pinned above the web view; the volume-nav
    /// bar is below (Research + side-by-side mode only). The Research rail is either side-by-side
    /// (≥ the breakpoint) or a trailing overlay (below it).
    private func webKitDocumentView(renderModel: FRUSDocumentRenderModel) -> some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= Self.railOverlayBreakpoint
            ZStack(alignment: .trailing) {
                // Document column + the side-by-side Research rail (Phase C1), shown beside the
                // document only when there's room (≥ ~900 pt). Mounted here so both hosts
                // (MainWindowView + MacDocumentWindowView) inherit it; gated on `panelVisible` (⌘⇧R).
                HStack(spacing: 0) {
                    documentColumn(renderModel: renderModel, wide: wide)
                    if panelVisible && wide {
                        Divider()
                        researchRail(width: 300)
                    }
                }

                // Narrow (< ~900 pt): the rail floats as a trailing overlay (leading shadow + ×
                // close, mock 04) so the document keeps full width and never reflows below the
                // reading floor (C2.3). Manual overlay, NOT `.inspector` (which can't overlay).
                if panelVisible && !wide {
                    HStack(spacing: 0) {
                        Divider()
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { panelVisible = false }
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.borderless)
                                .help(String(localized: "researchRail.overlay.close.help",
                                             defaultValue: "Close research panel"))
                                .accessibilityLabel(String(localized: "researchRail.overlay.close.a11y",
                                                           defaultValue: "Close research panel"))
                                .padding(8)
                            }
                            researchRail(width: 300)
                        }
                        .frame(width: 300)
                        // Opaque so the full-width document underneath doesn't ghost through the
                        // panel (C2b review D6); `.compositingGroup()` flattens the panel so the
                        // shadow traces its silhouette instead of haloing every element inside (D2).
                        .background(Color(nsColor: .windowBackgroundColor))
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.15), radius: 8, x: -2, y: 0)
                    }
                    .transition(.move(edge: .trailing))
                }
            }
            // GeometryReader lays its child out .topLeading; fill the reader so the document column
            // (which relies on the caller's greedy frame) spans it.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: panelVisible)
            // Toggling the rail changes the web view's WIDTH → WKWebView reflows every line, but the
            // DOM selection doesn't change, so no `selectioncleared` fires and the bar would strand on
            // its pre-reflow anchor. Drop it on toggle (C1b review F4; applies in both rail modes).
            .onChange(of: panelVisible) { _, _ in
                selectionBar.hideNow()
                // The edge chevrons unmount when the rail opens; `onHover(false)` isn't guaranteed on
                // unmount, so clear the hover state or a stale edge stays "armed" (C2b review D3).
                hoveredNavEdge = nil
            }
            // The bar's Excerpt action presents the collection picker in excerpt mode (Phase B2),
            // sharing the C1a-unified `CollectionPickerSheet`.
            .sheet(isPresented: $showAddExcerpt, onDismiss: { pendingExcerptCapture = nil }) {
                if let capture = pendingExcerptCapture {
                    CollectionPickerSheet(entry: entry, excerpt: capture)
                }
            }
            // Dismiss the bar when this document view is navigated away from (pop-back zombie — see
            // Phase B2). NavigationStack retains pushed instances with their @State.
            .onDisappear {
                selectionBar.hideNow()
                hoveredNavEdge = nil
                findController.hide()   // #363 #5: same pop-back zombie guard — don't resurface a stale find bar.
            }
        }
    }

    /// The Research rail wired to this document's actions. Extracted so the side-by-side and
    /// overlay presentations (C2.3) share one construction; width is applied by the caller.
    @ViewBuilder
    private func researchRail(width: CGFloat) -> some View {
        ResearchRailView(
            entry: entry,
            vm: vm,
            pendingHighlightLink: highlightCoordinator.pendingHighlightLink,
            onAddNote: { openNoteComposer() },
            onEditNote: { note in openNoteComposer(noteId: note.id) },
            onAddNoteToHighlight: { highlightId in
                // Restore the highlight-linked note path the retired strip carried (C1b review F1):
                // compose a note linked back to the just-created highlight.
                openNoteComposer(linkedHighlightId: highlightId)
                highlightCoordinator.pendingHighlightLink = nil
            },
            onClassificationChanged: {
                // #279 / W-4: reload so the body's shape follows the new classification.
                Task {
                    guard let dm = appState.downloadManager else { return }
                    await vm.load(volumeURL: dm.volumeURL(for: entry.volumeId))
                }
            })
            .frame(width: width)
    }

    /// The document column — identity header, web-view body (with the floating selection-bar
    /// overlay), and the volume-navigation bar (Research mode only) — the leading member of the
    /// `webKitDocumentView` HStack, beside the Research rail.
    private func documentColumn(renderModel: FRUSDocumentRenderModel, wide: Bool) -> some View {
        VStack(spacing: 0) {
            // Identity + highlights banner (non-scrollable header)
            documentIdentityView
                .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 10)

            Divider()

            // Change banner (R-5 P2): a recorded update to this document and/or stored highlights
            // whose renderingVersion doesn't match the current one. One shared view for both twins.
            let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: renderModel)
            DocumentChangeBanner(revision: revision,
                                 highlightsStale: highlights.contains { $0.renderingVersion != renderingVersion },
                                 onReview: { showReviewChanges = true })

            // Document body — WKWebView handles scrolling, tables, footnotes, and highlights.
            FRUSDocumentWebView(
                model: renderModel,
                footnoteAnchor: revealedFootnoteAnchor,
                onPersonTap: { person in
                    vm.selectedPerson = person
                    if let person {
                        handlePersonTap(person)
                    } else {
                        showPersonNotFound = true
                    }
                },
                onGlossTap: { entry in
                    if let entry {
                        handleGlossTap(entry)
                    } else {
                        showGlossNotFound = true
                    }
                },
                onCrossRefTap: { target, volumeId in
                    handleCrossRefTap(target: target, volumeId: volumeId)
                },
                onBrokenRefTap: { info in
                    brokenRefExplanation = info
                }
            )
            .highlights(highlights)
            .findController(findController)   // #363 #5: ⌘F find-in-document
            .onSelectionChanged { selection in
                if selection.hasOffsets {
                    highlightCoordinator.webKitSelectionRange = (selection.start, selection.end)
                    highlightCoordinator.webKitSelectedBlockText = nil
                } else {
                    // Footnote selection: text available but no valid offset range. Keep the
                    // enclosing note body so the NARA lookup can characterise its citations (#269).
                    highlightCoordinator.webKitSelectionRange = nil
                    highlightCoordinator.webKitSelectedBlockText =
                        selection.blockText.isEmpty ? nil : selection.blockText
                }
                highlightCoordinator.webKitSelectedText = selection.text.isEmpty ? nil : selection.text
                // Drive the floating selection bar (Phase B2) straight from the payload. macOS never
                // magnifies, so the rect maps 1:1 to view points (no zoom gate). A footnote/
                // out-of-document selection disables the dots + Excerpt, keeping Look Up + Note.
                if let rect = selection.rect, !selection.text.isEmpty {
                    selectionBar.present(rect: rect, atFootnote: !selection.hasOffsets)
                } else {
                    selectionBar.hideNow()
                }
            }
            .onSelectionCleared {
                highlightCoordinator.webKitSelectionRange = nil
                // webKitSelectedText intentionally preserved for NARA lookup.
                // Debounced so the bar survives a spurious clear; a real clear lets it elapse.
                selectionBar.scheduleHide()
            }
            .onSelectionScrolled {
                // The anchor rect is stale after a scroll; hide the bar immediately.
                selectionBar.hideNow()
            }
            .onHighlightTapped { start, end in
                highlightToDelete = (start, end)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Read-mode hover-revealed prev/next chevrons (C2.4) — the rail-off replacement for the
            // volume-nav bar. On the web view so they sit at the reading edges, vertically centred.
            // Declared BEFORE the selection bar so the bar wins the z-order when both want the same
            // edge — an armed-but-invisible chevron must never intercept a Look Up/Note tap (D3).
            .overlay(alignment: .leading)  { edgeNavChevron(.leading) }
            .overlay(alignment: .trailing) { edgeNavChevron(.trailing) }
            .overlay {
                macFloatingSelectionBarOverlay
            }
            // #363 #5: the find bar pins to the top of the document when ⌘F is pressed.
            .overlay(alignment: .top) {
                if findController.isBarVisible {
                    DocumentFindBar(controller: findController)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Volume navigation bar — Research mode only (C5), and only side-by-side (`wide`). In the
            // narrow OVERLAY mode the trailing rail floats over the document's right edge, so a
            // full-width nav bar here would put its Next button UNDER the opaque panel — a dead
            // control (C2b review D1). There prev/next stay on the ⌥⌘↑/↓ Document-menu commands. In
            // Read mode both modes fall back to those commands + the hover edge chevrons.
            if panelVisible && wide {
                Divider()
                volumeNavigationView
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Floating Selection Bar (Research-rail Phase B2)

    /// The macOS floating selection bar overlay: the shared ``FloatingSelectionBar`` anchored
    /// *above* the selection (D3 — macOS has no system selection callout to compete with) on the
    /// web view. The dots create a highlight; Excerpt/Look Up/Note reuse the same actions the
    /// Research rail and Document menu drive.
    @ViewBuilder
    private var macFloatingSelectionBarOverlay: some View {
        GeometryReader { proxy in
            if let anchor = selectionBar.anchor {
                FloatingSelectionBar(
                    atFootnote: selectionBar.atFootnote,
                    compact: false,
                    onHighlight: { color in
                        createWebKitHighlight(color: color)
                        selectionBar.hideNow()
                    },
                    onExcerpt: {
                        if let capture = makeSelectionExcerptCapture() {
                            pendingExcerptCapture = capture
                            showAddExcerpt = true
                        }
                        selectionBar.hideNow()
                    },
                    onLookUp: {
                        lookUpSelectionInNARA()
                        selectionBar.hideNow()
                    },
                    onNote: {
                        openNoteComposer()
                        selectionBar.hideNow()
                    }
                )
                .modifier(FloatingSelectionBarPositioner(
                    selection: anchor, container: proxy.size, below: false))
            }
        }
        .allowsHitTesting(selectionBar.isVisible)
        .animation(.easeOut(duration: 0.25), value: selectionBar.isVisible)
    }

    /// Hands the current selection to the Source Explorer window's NARA Lookup segment (the B3
    /// hand-off), done directly here so the floating bar needs no closure threaded through the
    /// window host.
    private func lookUpSelectionInNARA() {
        // Guard against an empty query (e.g. the strip's NARA button already consumed the text
        // while the bar was still visible) — don't open the Source Explorer with a blank lookup.
        guard let text = highlightCoordinator.webKitSelectedText, !text.isEmpty else { return }
        appState.pendingNARALookup = NARALookupRequest(
            text: text, blockContext: lookupContext())
        highlightCoordinator.webKitSelectedText = nil
        highlightCoordinator.webKitSelectedBlockText = nil
        // #369 BUG-8: this NARA lookup ALSO opens the shared Source Explorer window (the other of
        // its two openers). Re-assert THIS window's document into the source-note globals — another
        // document window's `loadDocument()` may have overwritten them — so if the user flips the
        // segmented control to "Source Note" it shows THIS document rather than whichever window
        // loaded last. Mirrors `openSources()`; uses the same non-nil note value.
        //
        // #363: do NOT bump `sourceNoteFocusID` here. The Source Explorer window learns to switch to
        // the NARA Lookup segment from the `pendingNARALookup` hand-off itself (its
        // `.onChange(of: pendingNARALookup)` snapshots the note THEN consumes the lookup). Bumping the
        // focus id too would ALSO trip the window's note-focus handler, racing it back to Source Note
        // (the bug that made an already-open lookup land on "Source Note"). Keeping the two signals
        // disjoint — pendingNARALookup here, sourceNoteFocusID only in `openSources` — is what makes
        // the segment switch deterministic.
        appState.currentSourceNoteYear       = Self.extractYear(from: entry.dateline)
        appState.currentSourceNoteHeader     = entry.header
        appState.currentSourceNoteDateline   = entry.dateline
        appState.currentSourceNoteVolumeId   = entry.volumeId
        appState.currentSourceNoteDocumentId = entry.documentId
        appState.currentSourceNote           = vm.sourceNote ?? entry.sourceNote ?? ""
        // A tool-window launch from a document host — stamp provenance (last-spawner-wins)
        // so the Source Explorer's related-document taps route back to THIS window.
        appState.bindTool(.sourceExplorer, to: documentHostID)
        openWindow.fronting(id: "frus.sourceExplorer")
    }

    // MARK: - Document Year Extraction

    /// Extracts a 4-digit year from a dateline string.
    /// Duplicated from DocumentView (which is `#if os(iOS)`), kept here so MacDocumentView has no
    /// cross-file dependency. It first tries the strict "Month D, YYYY" parse
    /// (`CentralFilesClassifier.datelineDateISO`) so a stray 4-digit token in a footnote-bearing
    /// dateline blob can't hijack the year via first-match, then falls back to a loose 18xx–20xx
    /// (through 2029) scan. Widening to 18xx lets pre-1906 FRUS datelines reach pre-1906
    /// country-series resolution (issue #215); keep identical to `DocumentView.extractYear` and
    /// the inline extractor in `SupportingViews`.
    static func extractYear(from dateline: String?) -> Int? {
        guard let dl = dateline else { return nil }
        if let iso = CentralFilesClassifier.datelineDateISO(from: dl),
           let year = Int(iso.prefix(4)) {
            return year
        }
        let pattern = #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: dl, range: NSRange(dl.startIndex..., in: dl)),
              let range = Range(match.range(at: 1), in: dl)
        else { return nil }
        return Int(dl[range])
    }

    /// The "Document" menu's command surface for this document (UI audit gap 6),
    /// published as the `\.documentCommands` focused-scene value.
    ///
    /// Every closure routes to an action that already exists as a button: prev/next
    /// mirror `volumeNavigationView`, add-note mirrors the rail's "Add
    /// Note" (`openNoteComposer`), highlight mirrors the floating bar's colour
    /// dots (`createWebKitHighlight`), and the panel toggle mirrors the rail's
    /// Read/Research picker (same `AppStorage` key). Equality contract (see
    /// `DocumentCommandActions`): the closures capture only `prevEntry`/`nextEntry`,
    /// which are loaded once per document — any change to them flips
    /// `canGoPrevious`/`canGoNext` (or `documentKey`), forcing a republish, so a
    /// stale closure can never survive an equality check.
    private var documentCommands: DocumentCommandActions? {
        DocumentCommandActions(
            documentKey: "\(entry.volumeId)/\(entry.documentId)",
            canGoPrevious: prevEntry != nil,
            canGoNext: nextEntry != nil,
            canHighlight: highlightCoordinator.webKitSelectionRange != nil,
            isResearchPanelVisible: panelVisible,
            goPrevious: { if let prev = prevEntry { navigationPath.append(prev) } },
            goNext: { if let next = nextEntry { navigationPath.append(next) } },
            addNote: { openNoteComposer() },
            highlightSelection: { color in createWebKitHighlight(color: color) },
            toggleResearchPanel: {
                withAnimation(.easeInOut(duration: 0.2)) { panelVisible.toggle() }
            },
            openInNewWindow: {
                // File ▸ "Open Document in New Window" (C2.2). Value-based identity is
                // (volumeId, documentId), so this focuses the window if the document is already open.
                // Mint from the full entry (widened payload → full chrome) with the live title override.
                var id = DocumentWindowID(entry: entry)
                id.header = vm.documentTitle ?? entry.header
                openWindow(value: id)
            },
            canFindInDocument: true,   // #363 #5: available whenever a document is loaded
            startFindInDocument: { findController.show() },
            findNext: { findController.find(forward: true) },
            findPrevious: { findController.find(forward: false) },
            printDocument: { printCurrentDocument() }
        )
    }

    /// Prints the document through its own web view — File ▸ Print (⌘P), M-14.
    ///
    /// The web view is reached the same way find is: `DocumentFindController` was handed the live
    /// `WKWebView` when the representable created it, so this reuses that reference rather than
    /// adding a second channel that could go stale independently.
    ///
    /// **The frame assignment is load-bearing.** `WKWebView.printOperation(with:)` returns an
    /// operation whose print view has a zero frame; run it bare and the sheet prints blank pages.
    /// Sizing it to the print info's imageable area is the documented workaround.
    private func printCurrentDocument() {
        guard let webView = findController.webView, let window = webView.window else { return }
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.view?.frame = NSRect(origin: .zero, size: info.imageablePageBounds.size)
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    /// Hands this document (and optionally an existing note) to the research-note
    /// composer window (UI audit C1) — the note is composed beside the document
    /// instead of in a sheet covering the passage being annotated.
    private func openNoteComposer(noteId: UUID? = nil, linkedHighlightId: UUID? = nil) {
        // #363: value-based open — the request carries the full composer context, so the window
        // rebuilds on restore and no longer needs a separate `pendingNoteComposer` hand-off. Opening
        // for the same request focuses the existing composer; a distinct request opens a new one.
        openWindow(value: NoteComposerRequest(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            noteId: noteId,
            linkedHighlightId: linkedHighlightId
        ))
    }

    // MARK: - Highlight Deletion

    /// Finds the `DocumentHighlight` matching the given flat-text offsets and
    /// deletes it from SwiftData. Called after the user confirms deletion via
    /// the tap-on-highlight context alert.
    @MainActor
    private func deleteHighlight(startOffset: Int, endOffset: Int) {
        // Match by volume + document + offsets — the combination is unique per highlight.
        let vid = entry.volumeId
        let did = entry.documentId
        let predicate = #Predicate<DocumentHighlight> { h in
            h.volumeId == vid && h.documentId == did
                && h.startOffset == startOffset && h.endOffset == endOffset
        }
        guard let hl = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first else {
            return
        }
        modelContext.delete(hl)
        #if DEBUG
        print("[MacDocumentView] Deleted highlight [\(startOffset)–\(endOffset)] from \(did)")
        #endif
    }

    /// The passage around the reader's selection, for the lookup's citation detection (#235).
    ///
    /// The hand-maintained twin of `DocumentView.lookupContext(vm:)` — see that one for why the
    /// widening happens in Swift rather than in the shared selection JavaScript. A footnote
    /// selection keeps its enclosing body; an ordinary body selection, which used to arrive with
    /// no context at all, gets a ± window out of the flat text.
    @MainActor
    private func lookupContext() -> String? {
        if let block = highlightCoordinator.webKitSelectedBlockText,
           !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return block
        }
        guard let range = highlightCoordinator.webKitSelectionRange,
              let model = vm.renderModel else { return nil }
        return flatTextExcerpt(from: model,
                               start: max(0, range.0 - NARALookupAnalyzer.contextBefore),
                               end: range.1 + NARALookupAnalyzer.contextAfter)
    }

    // MARK: - Highlight Actions (WebKit path)

    /// Creates a `DocumentHighlight` from the WebKit flat-text selection range.
    ///
    /// Called by `HighlightCoordinator.createWebKitHighlightAction` (registered in `.task`)
    /// when the user taps a colour dot on the floating selection bar while a selection is active.
    @MainActor
    private func createWebKitHighlight(color: DocumentHighlight.Color) {
        guard let range = highlightCoordinator.webKitSelectionRange,
              let model = vm.renderModel else { return }
        let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
        // Extract the selected text block-aware from the flat text so it's available
        // for display in the Research window without re-parsing — and so paragraph
        // breaks survive when the string is later frozen into an excerpt
        // (CollectionExcerpts.capture(from:)). Same canonicalization as iOS
        // `createHighlight` and both platforms' selection excerpt captures.
        let selectedText = flatTextExcerpt(from: model, start: range.0, end: range.1) ?? ""
        let highlight = DocumentHighlight(
            volumeId:         entry.volumeId,
            documentId:       entry.documentId,
            startOffset:      range.0,
            endOffset:        range.1,
            colorTag:         color.rawValue,
            selectedText:     selectedText,
            renderingVersion: renderingVersion
        )
        modelContext.insert(highlight)
        highlightCoordinator.webKitSelectionRange = nil
        highlightCoordinator.pendingHighlightLink = highlight.id
    }

    // MARK: - Excerpt Capture (Authoring Phase 5)

    /// Freezes the current WebKit selection into an excerpt capture (creation path b) —
    /// registered as `HighlightCoordinator.makeExcerptCaptureAction` so the research
    /// strip's Excerpt button captures through this view, which owns `vm.renderModel`.
    ///
    /// Mirrors iOS `DocumentView.selectionExcerptCapture`: when in-document offsets
    /// exist, the passage is re-extracted block-aware from the flat text
    /// (`flatTextExcerpt` — paragraph breaks restored, `data-skip` content such as
    /// footnote-marker digits excluded, exactly what a highlight of the same span
    /// stores) and the document's current `renderingVersion` is recorded. The raw
    /// `sel.toString()` text is used only for offset-less selections (footnotes),
    /// which freeze text-only with `nil` anchors — so stored anchors always delimit
    /// the flat-text span the frozen passage came from.
    ///
    /// - Returns: The capture, or `nil` when no selection text is available.
    @MainActor
    private func makeSelectionExcerptCapture() -> CollectionExcerptCapture? {
        var text = highlightCoordinator.webKitSelectedText ?? ""
        var start: Int? = nil
        var end: Int? = nil
        var renderingVersion: String? = nil
        if let range = highlightCoordinator.webKitSelectionRange,
           let model = vm.renderModel,
           let sliced = flatTextExcerpt(from: model, start: range.0, end: range.1) {
            text = sliced
            start = range.0
            end = range.1
            renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
        }
        guard !text.isEmpty else { return nil }
        return CollectionExcerptCapture(
            text: text,
            volumeId: entry.volumeId,
            documentId: entry.documentId,
            start: start,
            end: end,
            renderingVersion: renderingVersion,
            colorTag: nil)
    }

    // MARK: - Document Identity

    private var documentIdentityView: some View {
        HStack(spacing: 8) {
            if let docNum = entry.documentNumber {
                Text("Document \(docNum)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            Text(entry.volumeId)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if vm.effectiveIsEditorialNote ?? entry.isEditorialNote {
                EditorialNoteBadge()
            }
        }
    }

    // MARK: - Read-mode Edge Chevrons (C2.4)

    /// Leading/trailing edge chevrons for prev/next document.
    private enum NavEdge { case leading, trailing }

    /// A Read-mode (rail-off) hover-revealed prev/next affordance: a 34 pt circle vertically centred
    /// at the document's leading/trailing edge, reusing the volume reading-sequence
    /// `prevEntry`/`nextEntry` push. Hidden in Research mode (the `volumeNavigationView` bar owns
    /// prev/next there) and at volume boundaries (`prevEntry`/`nextEntry == nil`). ⌥⌘↑/↓ still work.
    @ViewBuilder
    private func edgeNavChevron(_ edge: NavEdge) -> some View {
        let target = edge == .leading ? prevEntry : nextEntry
        if !panelVisible, let target {
            Button {
                navigationPath.append(target)
            } label: {
                Image(systemName: edge == .leading ? "chevron.left" : "chevron.right")
                    // LEAVE-FIXED (Mac W-11): the chevron is centred in a fixed 34×34 hit
                    // circle; a scaled glyph would clip against it. The worklist's
                    // glyph-inside-a-fixed-shape carve-out.
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.black.opacity(0.05)))
                    // Hit region = the 34 pt circle only (NOT the padded frame), so a click anywhere
                    // else in the margin passes through to the web view. The inset below keeps it
                    // clear of the scrollbar.
                    //
                    // C2b review D3 argued the circle could not swallow a click while faded out,
                    // because a pointer cannot reach it without a `mouseEntered` revealing it
                    // first. That reasoning is now moot rather than wrong: M-9 made the chevron
                    // visible at rest, so there is no faded-out state to click into.
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            // 16 pt inset (not 8) so the circle sits inboard of the trailing overlay scrollbar band;
            // otherwise reaching for the scrollbar would land on this button instead (C2b review D3a).
            .padding(edge == .leading ? .leading : .trailing, 16)
            // **Visible, not hover-revealed** (UI review M-9). These were `opacity(0)` until the
            // pointer entered, which meant the mode named *Read* — the one for reading through a
            // volume — offered no visible way to turn the page at all: the bottom volume bar
            // renders only in Research mode, so a reader who never happened to sweep the margin
            // had ⌘⌥↑/↓ or nothing. An affordance you must already know about is not an
            // affordance.
            //
            // Hover still *emphasises* them, which keeps the quiet-until-wanted feel the original
            // was reaching for while leaving them discoverable. The resting opacity is deliberately
            // not 1: at full strength two circles sit in the margin of every document competing
            // with the text, which is what the hover-reveal was avoiding.
            .opacity(hoveredNavEdge == edge ? 1 : 0.35)
            .onHover { hoveredNavEdge = $0 ? edge : nil }
            .animation(.easeInOut(duration: 0.15), value: hoveredNavEdge)
            .help(String(localized: edge == .leading ? "document.nav.previous.help"
                                                     : "document.nav.next.help",
                         defaultValue: edge == .leading ? "Previous document in this volume"
                                                        : "Next document in this volume"))
            .accessibilityLabel(String(localized: edge == .leading ? "document.nav.previous.label"
                                                                   : "document.nav.next.label",
                                       defaultValue: edge == .leading ? "Previous document"
                                                                      : "Next document"))
        }
    }

    // MARK: - Volume Navigation

    private var volumeNavigationView: some View {
        HStack {
            if let prev = prevEntry {
                Button {
                    navigationPath.append(prev)
                } label: {
                    Label(
                        "Doc \(prev.documentNumber ?? prev.documentId)",
                        systemImage: "chevron.left"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(String(
                    localized: "document.nav.previous.help",
                    defaultValue: "Previous document in this volume"
                ))
            }

            Spacer()

            // Just the document's own identifier — no "of N in this volume" suffix.
            // `volumeEntry.documentCount` doesn't reflect the volume's true document
            // count (it read 0 for every volume), so that phrasing was always wrong;
            // the identifier alone is the part that's actually useful here.
            Text(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId)
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()

            if let next = nextEntry {
                Button {
                    navigationPath.append(next)
                } label: {
                    Label(
                        "Doc \(next.documentNumber ?? next.documentId)",
                        systemImage: "chevron.right"
                    )
                    .font(.subheadline)
                    .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(String(
                    localized: "document.nav.next.help",
                    defaultValue: "Next document in this volume"
                ))
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadDocument() async {
        // Clear the pre-populated source note so the Sources button can't show
        // stale data from the previous document while the new one is loading.
        appState.currentSourceNote = nil
        appState.currentSourceNoteYear = nil
        appState.currentSourceNoteHeader = nil
        appState.currentSourceNoteDateline = nil
        appState.currentSourceNoteVolumeId = nil
        appState.currentSourceNoteDocumentId = nil

        // Wait for the download manager to be bootstrapped if it isn't yet.
        // This can happen when a document is opened very early in the app lifecycle
        // (e.g. from a URL handler or Handoff) before bootApp() completes.
        var attempts = 0
        while appState.downloadManager == nil, attempts < 20 {
            try? await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        guard let dm = appState.downloadManager else { return }
        let volumeURL = dm.volumeURL(for: entry.volumeId)

        let volumeEntry = appState.manifestStore.entry(forVolumeId: entry.volumeId)
        vm = DocumentViewModel(
            entry: entry,
            volumeEntry: volumeEntry,
            parser: FRUSDocumentParser(),
            personMentionStore: appState.personMentionStore,
            astCache: appState.documentASTCache
        )
        // #279 / W-4: the effective classification — badge and body shape follow it.
        vm.effectiveClassificationLookup = { [weak appState] volumeId, documentId in
            guard let pipeline = appState?.indexingPipeline else { return nil }
            return (try? await pipeline.effectiveIsEditorialNote(
                volumeId: volumeId, documentId: documentId)) ?? nil
        }

        await vm.load(volumeURL: volumeURL)

        // Pre-populate appState.currentSourceNote from the live-parsed source note so the rail's
        // Sources tile always works, even when the DocumentBrowserEntry
        // was created via a cross-reference tap (which sets sourceNote: nil).
        // This ensures the macOS source explorer uses the same data source as iOS.
        let year = Self.extractYear(from: entry.dateline)
        appState.currentSourceNoteYear = year
        appState.currentSourceNoteHeader = entry.header
        appState.currentSourceNoteDateline = entry.dateline
        appState.currentSourceNoteVolumeId = entry.volumeId
        appState.currentSourceNoteDocumentId = entry.documentId
        // Set `currentSourceNote` unconditionally and non-nil, in lockstep with the metadata
        // fields above (esp. `currentSourceNoteDocumentId`, just set to this document's id). The
        // Source Explorer window binds to `currentSourceNote` and shows "No Document Selected"
        // ONLY when it is nil, while `openSources()` skips re-priming once
        // `currentSourceNoteDocumentId` matches the current document — trusting this block to have
        // populated the note. Leaving it nil for a note-less document whose dateline year didn't
        // parse therefore stranded the *loaded* document's window on "No Document Selected" (#410).
        // "" opens the explorer regardless: the country-series classifier resolves pre-1906 rolls
        // from the year/dateline, and a note-less modern document gets an empty-source state rather
        // than a false "no document". This matches `openSources()`'s own `entry.sourceNote ?? ""`.
        appState.currentSourceNote = vm.sourceNote ?? entry.sourceNote ?? ""

        vm.recordReadingHistory(projectId: appState.activeProjectId, in: modelContext)
        vm.loadSummaries(context: modelContext)
        vm.refreshCrossProjectNoteCount(
            activeProjectId: appState.activeProjectId,
            context: modelContext
        )

        // Load adjacent entries for prev/next navigation buttons. The reading
        // sequence spans the whole volume — front matter, body, and back matter —
        // so Prev/Next never skips structured front-matter sections (Persons,
        // Sources, Table of Contents, Index) the search index leaves out.
        if let pipeline = appState.indexingPipeline {
            if let docs = try? await pipeline.readingSequence(forVolume: entry.volumeId),
               let idx = docs.firstIndex(where: { $0.documentId == entry.documentId }) {
                prevEntry = idx > 0 ? docs[idx - 1] : nil
                nextEntry = idx + 1 < docs.count ? docs[idx + 1] : nil
            }
        }

        #if DEBUG
        print("[MacDocumentView] Loaded \(entry.volumeId)/\(entry.documentId)")
        #endif
    }

    /// Routes a tapped in-document cross-reference through
    /// `FRUSURLSchemeHandler.resolveCrossRefTarget` (Session 162). The previous
    /// implementation only stripped a *leading* `#`, so cross-volume targets
    /// (`frus1964-68v18#d65`) navigated to a bogus document ID, and it silently
    /// skipped printed-page references instead of resolving them.
    private func handleCrossRefTap(target: String, volumeId: String?) {
        switch FRUSURLSchemeHandler.resolveCrossRefTarget(target, volumeId: volumeId) {
        case .document(let targetVolumeId, let documentId):
            navigateToCrossRef(documentId: documentId,
                               volumeId: targetVolumeId ?? entry.volumeId)

        case .footnote(let targetVolumeId, let documentId, let anchor):
            navigateToCrossRef(documentId: documentId,
                               volumeId: targetVolumeId ?? entry.volumeId,
                               footnoteAnchor: anchor)

        case .page(let targetVolumeId, let page):
            resolvePageReference(page: page,
                                 volumeId: targetVolumeId ?? entry.volumeId)

        case .external(let url):
            openURL(url)

        case .unresolved:
            #if DEBUG
            print("[MacDocumentView] Cross-ref skipped (unresolvable target): \(target)")
            #endif
        }
    }

    /// Pushes `documentId` in `volumeId` onto the navigation stack, or — when the
    /// target volume isn't downloaded — prompts to download it rather than pushing
    /// into a guaranteed load failure (mirrors the iOS cross-ref guard).
    private func navigateToCrossRef(documentId: String, volumeId: String,
                                    footnoteAnchor: String? = nil) {
        guard !documentId.isEmpty else { return }
        // #988: a note in the document already open is revealed in place. Pushing would stack a
        // second copy of the document the reader is reading — the iOS twin makes the same call.
        if let footnoteAnchor, documentId == entry.documentId, volumeId == entry.volumeId {
            revealedFootnoteAnchor = footnoteAnchor
            return
        }
        if let dm = appState.downloadManager, !dm.isVolumeDownloaded(volumeId) {
            crossRefDownloadVolumeId = volumeId
            #if DEBUG
            print("[MacDocumentView] Cross-ref: \(volumeId) not downloaded, offering download")
            #endif
            return
        }
        let dest = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            // Use the ID as placeholder header — loadDocument() fills the real title
            // after parsing, matching the breadcrumb approach.
            header: documentId,
            footnoteAnchor: footnoteAnchor
        )
        navigationPath.append(dest)

        #if DEBUG
        print("[MacDocumentView] Cross-ref tap → \(volumeId)/\(documentId)")
        #endif
    }

    /// Resolves a printed-page reference to its containing document and opens it.
    private func resolvePageReference(page: Int, volumeId: String) {
        guard let store = appState.pageRangeStore else {
            #if DEBUG
            print("[MacDocumentView] Page ref: PageRangeStore unavailable")
            #endif
            return
        }
        Task {
            let documentId = (try? await store.document(forPage: page, inVolume: volumeId)) ?? nil
            await MainActor.run {
                if let documentId {
                    navigateToCrossRef(documentId: documentId, volumeId: volumeId)
                } else {
                    #if DEBUG
                    print("[MacDocumentView] Page ref: p. \(page) of \(volumeId) not in page index")
                    #endif
                }
            }
        }
    }

    private func handlePersonTap(_ person: PersonEntry) {
        vm.selectedPerson = person
        // Session 162 link audit: the count was never loaded on macOS, so the
        // person sheet always claimed "Not found in indexed documents".
        Task { await vm.loadPersonMentionCount(for: person) }
    }

    private func handleGlossTap(_ gloss: GlossEntry) {
        vm.selectedGloss = gloss
    }

}

// TagRowView removed — document-level subject tags are no longer shown in the UI.

// MARK: - TrailingIconLabelStyle

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - MacDocumentWindowView

/// Standalone macOS document window hosting one document as a full research
/// workspace — document column, trailing Research rail, and status bar — so a window opened
/// via `openWindow(value: DocumentWindowID(...))` is self-sufficient rather than a
/// bare document with no tools.
///
/// macOS gathers windows from the same `WindowGroup(for: DocumentWindowID.self)`
/// into native tabs (Window ▸ Merge All Windows / the window tab bar), which is how
/// a researcher views several documents as tabs in one frame. Each window owns its
/// own navigation stack and `HighlightCoordinator`, independent of the main window
/// and of every other document window.
///
/// Version history:
///   1.0 — Session 159: initial implementation (iPad/Mac parity Phase 2 —
///          macOS native window tabbing)
///   1.1 — Session 2026-07-04 (macOS UI audit B3): the NARA Catalog Lookup sheet
///          replaced by the Source Explorer window's NARA Lookup segment
///          (`pendingNARALookup` hand-off, mirroring `MainWindowView`)
struct MacDocumentWindowView: View {

    /// The document this window opened for.
    let windowID: DocumentWindowID

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    /// Whether this window is key — bumps this host's ADVISORY recency stamp in the live-host
    /// registry (fallback resolution only; provenance routing never samples focus).
    @Environment(\.controlActiveState) private var controlActiveState

    /// This window's routing identity — standalone document windows are keyed by their root
    /// `DocumentWindowID` (stable even after in-window navigation pushes other documents).
    private var hostID: DocumentHostID { .window(windowID) }

    /// The `NSWindow` hosting this view (captured by `HostWindowAccessor`) — used to
    /// deminiaturize on a routed delivery (`openWindow(value:)` re-fronts but does not restore a
    /// docked window).
    @State private var hostWindow: NSWindow?

    /// This window's own navigation stack — cross-reference taps push within the
    /// window rather than affecting the main window or other document windows.
    @State private var navigationPath: [DocumentBrowserEntry] = []
    /// This window's own highlight state (text selection, pending highlight link).
    @State private var highlightCoordinator = HighlightCoordinator()
    /// The shared research-panel visibility key — drives the D6 toolbar's rail toggle (⌘⇧R).
    @AppStorage("frus.document.researchPanel.visible") private var researchPanelVisible = true

    /// The document the window opened for, as a `DocumentBrowserEntry` — rebuilt from the widened
    /// `DocumentWindowID` payload so a minted window renders full document chrome (PR 2).
    private var rootEntry: DocumentBrowserEntry {
        windowID.rootEntry
    }

    /// The document currently shown (the navigation stack's top, or the root).
    private var currentEntry: DocumentBrowserEntry {
        navigationPath.last ?? rootEntry
    }

    /// The current document's volume in the app's short form, or `nil` when the manifest has no
    /// entry for it (UI review M-8).
    ///
    /// `nil` is a real state, not a defensive guard: a window restored from a previous session
    /// can name a volume that has since been removed from the manifest, which is the same case
    /// `MacDocumentView`'s restored-window empty state exists for.
    private var currentVolumeLabel: String? {
        guard let entry = appState.manifestStore.entry(forVolumeId: currentEntry.volumeId) else {
            return nil
        }
        return ChronologyViewModel.distilledVolumeLabel(volumeId: entry.volumeId,
                                                        subseries: entry.subseries,
                                                        title: entry.title)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $navigationPath) {
                MacDocumentView(
                    entry: rootEntry,
                    navigationPath: $navigationPath,
                    highlightCoordinator: highlightCoordinator
                )
                .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                    MacDocumentView(
                        entry: entry,
                        navigationPath: $navigationPath,
                        highlightCoordinator: highlightCoordinator
                    )
                }
            }

            StatusBarView()
        }
        // Window/tab title — the document's heading, falling back to its id.
        .navigationTitle(currentEntry.header.isEmpty ? currentEntry.documentId : currentEntry.header)
        // D6: the research strip is retired (C1), so this standalone document window surfaces its
        // identity + the rail toggle in a minimal toolbar. NARA + the selection verbs now live on the
        // floating selection bar (Phase B2) and the rail's Sources tile, so the strip's `onNARALookup`
        // hand-off is no longer needed here. (The main window's fuller 5-tool titlebar landed in C2a.)
        .toolbar {
            // UI review M-8. This carried `Text(currentEntry.documentId)` in monospace — a raw
            // `frus1946v06/d475` repeating identity the window title above already gives in human
            // form, with a `.help` repeating the title a third time. It now says what the title
            // does not: which volume, and where in it. See `MacDocumentTitle` for why the
            // finding's own remedy ("show the title") was the wrong one.
            ToolbarItem(placement: .principal) {
                let volumeLabel = currentVolumeLabel
                Text(MacDocumentTitle.principalLabel(volumeLabel: volumeLabel,
                                                     documentNumber: currentEntry.documentNumber,
                                                     documentId: currentEntry.documentId))
                    .font(MacDocumentTitle.isFallback(volumeLabel: volumeLabel)
                          ? .system(.body, design: .monospaced)
                          : .body)
                    .truncationMode(.middle)
                    // The id is still one hover away for anyone who wants to cite or file a bug
                    // against it — it moved out of the strip, it did not become unavailable.
                    .help(currentEntry.documentId)
            }
            ToolbarItem {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { researchPanelVisible.toggle() }
                } label: {
                    // Matches the main window's titlebar rail toggle (C2a): accent icon on an
                    // accent.opacity(0.12) rounded fill when on (C2a review F3, plan §5).
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(researchPanelVisible ? Color.accentColor : Color.secondary)
                        .padding(4)
                        .background(researchPanelVisible ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .help(String(localized: "researchRail.toggle.help",
                             defaultValue: "Research panel (⌘⇧R)"))
                .accessibilityLabel(String(localized: "researchRail.toggle.a11y",
                                           defaultValue: "Research panel"))
                .accessibilityIdentifier("researchRailToggle")
            }
        }
        .onChange(of: currentEntry) { _, _ in
            highlightCoordinator.reset()
        }
        // Provenance plumbing: launchers mounted in this window (rail tiles, sheets) read this
        // window's identity from the environment to stamp tool provenance.
        .environment(\.documentHostID, hostID)
        // Reliable close signal for host deregistration (onDisappear below is belt-and-braces).
        .background(HostWindowAccessor(
            onWindow: { hostWindow = $0 },
            onWillClose: { appState.unregisterHost(hostID) }
        ))
        .onAppear {
            appState.registerHost(hostID)
            // Drain a legacy navigation written while NO host was mounted (see MainWindowView).
            appState.routeLegacyPendingBrowse { orphan in
                openWindow(value: DocumentWindowID(entry: orphan))
            }
        }
        .onDisappear { appState.unregisterHost(hostID) }
        // Translate a LEGACY (origin-less, not-yet-migrated) tool-window navigation through the
        // fallback chain — done here too so translation survives when the main window is closed
        // and the user lives in document windows. Exactly-once via the clear-first step.
        .onChange(of: appState.pendingBrowseDocument) { _, entry in
            guard entry != nil else { return }
            appState.routeLegacyPendingBrowse { orphan in
                openWindow(value: DocumentWindowID(entry: orphan))
            }
        }
        // Bump this host's ADVISORY recency stamp while key — consulted only by the fallback
        // chain; provenance routing never samples focus.
        .onChange(of: controlActiveState, initial: true) { _, state in
            if state == .key { appState.hostBecameKey(hostID) }
        }
        // Consume a navigation routed to this window — push it onto this window's stack and bring
        // the window to the front (value-based openWindow focuses the existing window), so a route
        // into a backgrounded / minimized window isn't invisible. Re-read live state before
        // consuming so a stale captured value can't double-apply.
        .onChange(of: appState.routedBrowse) { _, routed in
            guard let routed, routed.host == hostID, appState.routedBrowse == routed else { return }
            navigationPath.append(routed.entry)
            appState.routedBrowse = nil
            // openWindow(value:) re-fronts the existing window but does not restore a docked one.
            if hostWindow?.isMiniaturized == true { hostWindow?.deminiaturize(nil) }
            openWindow(value: windowID)
        }
    }
}

// MARK: - DocumentFindController (#363 #5)

/// Drives find-in-document for a single macOS document web view (#363 #5).
///
/// macOS `WKWebView` has no native find bar (unlike iOS, where
/// `isFindInteractionEnabled` provides one), so this controller pairs the SwiftUI
/// ``DocumentFindBar`` with `WKWebView.find(_:configuration:)` — which selects and
/// scrolls to each match, wrapping at the document ends. There are no per-match
/// totals: WebKit's find API reports only whether the current search matched, so the
/// bar shows a "Not found" state rather than a "1 of N" count.
///
/// One controller is owned per document surface by `MacDocumentView` (`@State`), so
/// the main window and each standalone document window search their own document.
/// The web-view representable hands the controller its live `WKWebView` on creation.
///
/// Version history:
///   1.0 — #363 #5: initial implementation (⌘F Find in Document)
@MainActor
@Observable
final class DocumentFindController {

    /// The document's web view, handed over by the representable when it is created.
    /// Weak so closing the window doesn't keep the view alive through the controller.
    weak var webView: WKWebView?

    /// Whether the find bar is shown over the document.
    var isBarVisible = false

    /// The current query text (bound to the bar's text field).
    var query = ""

    /// Whether the most recent search matched — drives the bar's "Not found" state.
    /// Reset to `true` whenever the query is empty so an empty bar never reads
    /// "Not found".
    var matchFound = true

    /// Bumped by ``show()`` so the bar re-focuses its field even when it is already
    /// visible — pressing ⌘F again should return focus to the search field.
    private(set) var focusToken = 0

    /// Monotonic id of the most recently issued find. `WKWebView.find` is an async IPC
    /// round-trip whose completions can arrive out of order under fast typing, so each
    /// result is applied only if it is still the latest — otherwise a stale search's
    /// found/not-found state could clobber the current query's (#363 #5).
    private var findGeneration = 0

    /// Creates an idle controller (no web view attached yet).
    init() {}

    /// Shows the find bar and (re)focuses its field.
    func show() {
        isBarVisible = true
        focusToken &+= 1
    }

    /// Hides the find bar and drops the transient not-found state.
    func hide() {
        isBarVisible = false
        matchFound = true
    }

    /// Runs a find in the given direction from the current selection, wrapping at the
    /// document ends. A no-op (with a cleared not-found state) when the query is empty.
    func find(forward: Bool) {
        guard !query.isEmpty else {
            matchFound = true
            return
        }
        guard let webView else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = !forward
        configuration.caseSensitive = false
        configuration.wraps = true
        let currentQuery = query
        findGeneration &+= 1
        let generation = findGeneration
        Task { @MainActor in
            // A find failure is non-fatal (e.g. the page reloaded mid-search) — treat it as no match.
            let result = try? await webView.find(currentQuery, configuration: configuration)
            // Ignore a result superseded by a newer find (fast typing → out-of-order completions).
            guard generation == findGeneration else { return }
            matchFound = result?.matchFound ?? false
        }
    }
}

// MARK: - DocumentFindBar (#363 #5)

/// The macOS find-in-document bar (#363 #5) — a compact overlay pinned to the top of
/// the document, shown when its ``DocumentFindController`` is visible.
///
/// Find-as-you-type drives `WKWebView.find`; Return / the ⌄ button find the next
/// match, the ⌃ button finds the previous, and Escape / "Done" dismiss the bar.
///
/// Version history:
///   1.0 — #363 #5: initial implementation
struct DocumentFindBar: View {

    /// The controller that owns the query, visibility, and match state.
    @Bindable var controller: DocumentFindController

    /// Focus for the search field, so the bar takes focus the moment it appears.
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                String(localized: "document.find.field", defaultValue: "Find in Document"),
                text: $controller.query
            )
            .textFieldStyle(.plain)
            .focused($fieldFocused)
            .frame(minWidth: 180)
            .onSubmit { controller.find(forward: true) }
            .onChange(of: controller.query) { _, _ in controller.find(forward: true) }

            if !controller.matchFound, !controller.query.isEmpty {
                Text(String(localized: "document.find.notFound", defaultValue: "Not found"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button { controller.find(forward: false) } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(controller.query.isEmpty)
            .help(String(localized: "document.find.previous", defaultValue: "Find Previous"))

            Button { controller.find(forward: true) } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(controller.query.isEmpty)
            .help(String(localized: "document.find.next", defaultValue: "Find Next"))

            Button(String(localized: "document.find.done", defaultValue: "Done")) {
                controller.hide()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        .shadow(radius: 4, y: 2)
        .padding(10)
        .onAppear { fieldFocused = true }
        // Re-focus (⌘F while already open) — the controller bumps `focusToken`.
        .onChange(of: controller.focusToken) { _, _ in fieldFocused = true }
        // Escape dismisses the bar (standard find-bar behaviour).
        .onExitCommand { controller.hide() }
    }
}

#endif // os(macOS)
