// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import TipKit

// DocumentView and all its supporting types are iOS-only.
// macOS uses MacDocumentView (App/MacDocumentView.swift) with the new window-based architecture.
#if os(iOS)

// MARK: - DocumentSheet

/// Identifies which sheet is currently active in `DocumentView`.
///
/// A single enum replaces 7 independent `@State` boolean/optional sheet triggers.
/// SwiftUI can only present one sheet at a time; the enum makes that contract
/// explicit and eliminates impossible states (e.g. two sheets open simultaneously).
///
/// Version history:
///   1.0 — Session 59: initial implementation (F-024)
///   1.1 — Session 121: `addToCollection` case added (Bug 3 — iOS had no document-level
///          collection membership control; only tag-based membership was available)
enum DocumentSheet: Identifiable {
    case personDetail(PersonEntry)
    case glossDetail(GlossEntry)
    case citation
    case noteEditor
    case noteEditorForHighlight(UUID)
    case crossReferenceGraph
    case summarizePromptPicker
    case sourceExplorer(String)
    case editNote(ResearchNote)
    /// User-tag picker — lets the user toggle or create document-level tags on iOS.
    case tagPicker
    /// Collection picker — lets the user add this document to an existing collection
    /// or create a new one directly from the document view.
    case addToCollection
    /// Person link was tapped but the lookup returned nil — volume not indexed or
    /// persons list not yet available for this volume.
    case personNotFound
    /// Gloss link was tapped but the lookup returned nil.
    case glossNotFound
    /// User selected text in the document and chose "Look Up in NARA Catalog".
    case naraLookup(text: String)

    var id: String {
        switch self {
        case .personDetail(let p):             return "person-\(p.ref)"
        case .glossDetail(let g):              return "gloss-\(g.term)"
        case .citation:                        return "citation"
        case .noteEditor:                      return "noteEditor"
        case .noteEditorForHighlight(let hId): return "noteEditorForHighlight-\(hId)"
        case .crossReferenceGraph:             return "crossReferenceGraph"
        case .summarizePromptPicker:           return "summarizePromptPicker"
        case .sourceExplorer:                  return "sourceExplorer"
        case .editNote(let note):              return "editNote-\(note.id)"
        case .tagPicker:                       return "tagPicker"
        case .addToCollection:                 return "addToCollection"
        case .personNotFound:                  return "personNotFound"
        case .glossNotFound:                   return "glossNotFound"
        case .naraLookup:                      return "naraLookup"
        }
    }
}

// MARK: - DocumentView

/// Renders a single FRUS document using the TEI rendering pipeline.
///
/// ## Layout (top to bottom)
/// 1. Toolbar — research note, user tag, collection, citation, cross-reference, summarize actions
/// 2. Summary strip — active generated summary with "View others" control and chunked indicator
/// 3. Document body — `FRUSDocumentRenderer` with persName/gloss/ref callbacks
/// 4. Tag section — subject tag chips and user tag chips
/// 5. Cross-project note indicator — disclosure if notes from other projects exist
///
/// ## Accessibility
/// - Tag chips use the resolved pattern `"\(name), subject tag"` per spec §18.
/// - VoiceOver reading order: natural document order (header → dateline → body → tags).
///
/// ## Open Questions (resolved for Session 12)
/// - VoiceOver label: `"\(tagName), subject tag"` — confirmed by the spec note in §18.
/// - Reading order: natural SwiftUI layout order, top-to-bottom.
///
/// Version history:
///   1.0 — Session 12: initial implementation
///   1.1 — Session 20: add summarize toolbar button, prompt picker sheet, wasChunked indicator
///   1.2 — Session 23: add source explorer toolbar button and sheet
///   1.3 — Session 56: collapse 6–7 toolbar icons into 2 direct buttons + 1 overflow Menu
///          (HIG: ≤ 4 toolbar items on iPhone); Source Explorer, Cross-References,
///          Summarize, and Citation sub-actions move inside the overflow "More" menu
///   1.3 — Session 27: Q5 curated badge icon; Q1 confidence-aware a11y label; tag hint
///   1.4 — Session 40: personMentionStore wired; PersonDetailSheet gains mention count + Find all mentions
///   1.5 — Session 44: handleCrossRefTap wired cross-platform via pendingBrowseDocument
///   1.6 — Session 54: OpenURLAction handles frusexplorer://doc/… links from AttributedString cross-refs
///   1.7 — Session 59: consolidate 7 sheet modifiers into single .sheet(item: $activeSheet) via
///          DocumentSheet enum (F-024); add .presentationDetents on PersonDetail/Gloss/Citation (F-006)
///   1.8 — Session 65: pass `embedInScrollView: false` to FRUSDocumentRenderer to eliminate
///          nested ScrollViews (fixes scroll-stuck bug and unblocks link/tap hit-testing);
///          extend \.openURL handler to route frusexplorer://person/ and frusexplorer://gloss/
///          URLs to the person/gloss detail sheets via vm.personsByRef / vm.termsByRef
///   1.9 — Session 66: fix empty navigation title and breadcrumb for cross-reference targets;
///          navigationTitle now uses vm.documentTitle (set after parse) falling back to
///          entry.header or entry.documentId; handleCrossRefTap uses docId as placeholder header
///          so the breadcrumb is non-empty while the document loads
///   2.0 — Session 68: fix cross-reference and search-result document loading. Both paths
///          reached DocumentView as a prop update on an existing view instance (NavigationSplitView
///          detail column reuse), leaving vm stale for the old entry. Replaced .onAppear with
///          .task(id: documentId/volumeId): the task auto-cancels and restarts when the entry
///          identity changes, resetting vm and re-bootstrapping for the new document. Same-entry
///          reappearance is a no-op because bootstrapViewModel guards on vm == nil.
///   2.1 — Session 92: FRUSTheme tokens applied — documentHorizontalPadding replaces
///          .padding(.horizontal) magic numbers; sectionLabelSize/Weight/Kerning on the
///          tag section header; tagChipSpacing on the chip row; EditorialNoteBadge added
///          at the top of the document body for editorial note entries (iOS parity with macOS)
///   2.2 — Session 104: highlight mode toolbar toggle + DocumentHighlightTextView (UITextView
///          UIViewRepresentable) + color-picker sheet + DocumentHighlight SwiftData insertion
///   2.3 — Session 105: renderingVersion uses SHA-256(flatText ++ kVersion) via
///          ASTToRenderNodeConverter.renderingVersion(for:)
///   2.4 — Session 106: @Query for stored highlights; overlay rendering; stale warning banner;
///          DocumentSheet.noteEditorForHighlight; note anchoring to highlights
///   2.5 — Session 107: iPad (.regular) side panel for research notes; DocumentSheet.editNote;
///          @Query documentNotes; iPadDocumentLayout + notesPanel
///   2.6 — Session 108: @Environment(\.openWindow); Source Explorer opens in new window on iPad;
///          "Open in New Window" menu item routes to DocumentWindowID Stage Manager scene
///   2.7 — Session 109: Notes panel hidden during highlight mode; notesPanel frame fill fix;
///          note count badge; CollectionEditorView iPadCollectionLayout frame fix
///   2.8 — Session 110: Replace HStack notes panel with .inspector(isPresented:) — system-
///          managed width, collapsible; Notes toggle button in .topBarLeading (iPad only);
///          toggleHighlightMode() closes inspector; remove iPadDocumentLayout HStack
///   2.9 — Session 120: DocumentSheet.tagPicker added; tag toolbar button wired to show
///          TagPickerSheetView (replaces empty Session-14 stub on iOS)
///   3.0 — Session 121: TagPickerSheetView now saves tag associations via IndexingPipeline
///          (Bug 2 — selected tags were stored in @State only and lost on dismiss);
///          DocumentSheet.addToCollection + CollectionPickerSheetView added (Bug 3 — iOS
///          had no document-level collection membership control); "Add to Collection"
///          button added to moreMenu
///   3.1 — Session 2026-06-07: edge-tap "page-turn" navigation — invisible
///          leading/trailing tap zones (documentEdgeNavigationOverlay) open the
///          previous/next document in the volume, ebook-reader style. Active only
///          in Read mode (!panelVisible — the existing "Read"/"Research" segmented
///          toggle) so research-mode interaction (selection, highlighting, panel
///          use) is never disrupted by inadvertent edge taps. Adjacent entries are
///          resolved by DocumentViewModel.loadAdjacentEntries, mirroring
///          MacDocumentView's existing prevEntry/nextEntry chevron buttons.
///   3.2 — Session 2026-06-07: removed the app-owned "More" `Menu` wrapper
///          (and its nested Citation sub-menu) from the iOS document toolbar.
///          On iPhone the items overflowed into the system's own "···"
///          button, which then contained our "More" — a wasted, confusing
///          two-level "···" → "More" → tools hierarchy. All actions (Citation
///          view/copy, Add to Collection, Cross-References, NARA Lookup,
///          Source Explorer, Open in New Window, Summarize) now sit as flat,
///          direct items in the single `ToolbarItemGroup(placement:
///          .primaryAction)`; the system overflow — when triggered — is the
///          one and only "···" menu and surfaces every tool in one tap.
///   3.3 — Session 2026-06-07: added "Share Citation" to the document
///          toolbar — a `ShareLink` presenting the system share sheet with a
///          message combining the formatted citation and the document's
///          canonical history.state.gov URL (`DocumentViewModel
///          .shareableCitationMessage`), mirroring the new "Share Citation"
///          item added to the macOS citation popover's Export menu.
///   3.4 — Session 154: added Reading preferences — edge-tap page-turn zones
///          can be disabled (`edgeTapNavigationEnabled`), and a default
///          document mode (Read/Research/remember-last) is applied to
///          `panelVisible` once per document open.
///   3.5 — Session 159: "Open in New Window" gated on
///          `@Environment(\.supportsMultipleWindows)` instead of
///          `sizeClass == .regular` (iPad/Mac parity Phase 5). The size-class
///          proxy is true on every iPad, so the button previously appeared for
///          all iPad users but `openWindow` silently no-ops without Stage
///          Manager; the new gate offers it only when a second window can open.
struct DocumentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let entry: DocumentBrowserEntry

    @State private var vm: DocumentViewModel?
    /// Drives the single consolidated sheet for all DocumentView-level presentations (F-024).
    @State private var activeSheet: DocumentSheet?
    /// Selected detent for the cross-reference graph sheet; starts at `.large`
    /// so the graph never opens half-height (Session 161).
    @State private var graphSheetDetent: PresentationDetent = .large

    // MARK: Highlight state
    @State private var showHighlightColorPicker = false
    /// The `DocumentHighlight.id` of the most recently created highlight.
    /// Non-nil while the "Add Note to Highlight" toolbar button should be enabled.
    @State private var pendingHighlightLink: UUID? = nil
    /// WebKit selection range — `(start, end)` Unicode-scalar offsets.
    /// Set by `onSelectionChanged` from `FRUSDocumentWebView`.
    @State private var webKitSelectionRange: (Int, Int)? = nil
    /// Raw selected text from the WebKit renderer. Pre-populates the NARA lookup field.
    @State private var webKitSelectedText: String? = nil
    /// Offsets of a tapped highlight pending the user's delete confirmation.
    @State private var highlightToDelete: (Int, Int)? = nil
    /// Research panel accordion state (persisted; shared with macOS via AppStorage).
    @AppStorage("frus.document.researchPanel.visible")  private var panelVisible    = true
    @AppStorage("frus.document.researchPanel.summary")  private var summaryExpanded = true
    @AppStorage("frus.document.researchPanel.notes")    private var notesExpanded   = true
    @AppStorage("frus.document.researchPanel.tags")     private var tagsExpanded    = false
    /// Whether the Read-mode edge-tap "page-turn" zones are active (Session 154).
    @AppStorage(SettingsKeys.edgeTapNavigationEnabled) private var edgeTapNavigationEnabled = true
    /// Which mode (Read/Research/remember-last) a document opens in (Session 154).
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast
    /// Controls the trailing notes inspector panel (iPad only; on iPhone the button
    /// that sets this is hidden, keeping the panel closed).
    @State private var showNotesPanel = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openWindow) private var openWindow
    /// Opens external (non-FRUS) cross-reference URLs in the system browser.
    @Environment(\.openURL) private var openURL
    /// `true` only when the platform can actually open a second window — Stage
    /// Manager on iPad; never on iPhone or a non-Stage-Manager iPad. Gates the
    /// "Open in New Window" affordance so it isn't offered where `openWindow`
    /// would silently no-op. `sizeClass == .regular` is true on *all* iPads and
    /// is therefore the wrong proxy for multi-window capability.
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    @Query private var highlights:             [DocumentHighlight]
    @Query private var documentNotes:          [ResearchNote]
    @Query private var documentTagAssignments: [DocumentTagAssignment]
    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]

    // MARK: - Init

    init(entry: DocumentBrowserEntry) {
        self.entry = entry
        let vId = entry.volumeId
        let dId = entry.documentId
        self._highlights = Query(
            filter: #Predicate<DocumentHighlight> { h in
                h.volumeId == vId && h.documentId == dId
            },
            sort: \DocumentHighlight.createdAt
        )
        self._documentNotes = Query(
            filter: #Predicate<ResearchNote> { n in
                n.volumeId == vId && n.documentId == dId
            },
            sort: \ResearchNote.lastModified,
            order: .reverse
        )
        self._documentTagAssignments = Query(
            filter: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
    }

    var body: some View {
        Group {
            if let vm {
                loadedView(vm: vm)
            } else {
                ProgressView(String(localized: "document.initializing",
                                    defaultValue: "Opening document…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Use .task(id:) rather than .onAppear so that SwiftUI auto-cancels and
        // restarts the task whenever the entry identity changes. This is necessary
        // because NavigationSplitView reuses the same DocumentView instance when the
        // detail column's last path element changes from one .document entry to another
        // (cross-reference taps and search-result selections both hit this path).
        // When reused, `entry` is updated as a prop but `@State var vm` retains the
        // old DocumentViewModel — so the body shows the old document until we reset.
        //
        // The id string encodes both documentId and volumeId so cross-volume references
        // (same docId, different volume) also trigger a reset.
        .task(id: entry.documentId + "/" + entry.volumeId) {
            // Reset vm if we detect view reuse for a different entry.
            // bootstrapViewModel() alone is not enough because it guards on vm == nil.
            if let existingVm = vm,
               existingVm.entry.documentId != entry.documentId
                   || existingVm.entry.volumeId != entry.volumeId {
                vm = nil
                pendingHighlightLink = nil
            }
            // Apply the default document mode on open. .rememberLast leaves
            // panelVisible untouched, preserving the prior cross-document
            // persistence; .read/.research force it, but the in-document
            // segmented control can still switch modes live afterwards.
            switch defaultDocumentMode {
            case .read:         panelVisible = false
            case .research:     panelVisible = true
            case .rememberLast: break
            }
            bootstrapViewModel()
            appState.logEvent(.documentOpen(
                volumeId: entry.volumeId,
                documentId: entry.documentId,
                title: entry.header.isEmpty ? entry.documentId : entry.header
            ))
        }
        // vm.documentTitle is set after the document loads; it provides a real
        // title for cross-reference targets, which are created with header: "".
        // Falls back to entry.header (known at browse time) or to entry.documentId
        // as a last resort so the navigation bar is never blank.
        .navigationTitle(vm?.documentTitle ?? (entry.header.isEmpty ? entry.documentId : entry.header))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .userActivity(AppActivityTypes.document, element: entry) { entry, activity in
            activity.title = entry.header.isEmpty ? entry.documentId : entry.header
            activity.userInfo = ["volumeId": entry.volumeId, "documentId": entry.documentId]
            activity.isEligibleForHandoff = true
        }
    }

    // MARK: - Bootstrap

    private func bootstrapViewModel() {
        guard vm == nil else { return }
        let allVolumes = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let volumeEntry = allVolumes.first { $0.volumeId == entry.volumeId }
        vm = DocumentViewModel(
            entry: entry,
            volumeEntry: volumeEntry,
            parser: FRUSDocumentParser(),
            subjectTagStore: appState.subjectTagStore,
            personMentionStore: appState.personMentionStore,
            astCache: appState.documentASTCache
        )
        guard let vm else { return }
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        let url = dm.volumeURL(for: entry.volumeId)
        // Live-parse the publication year from the volume's TEI XML so the
        // citation tools show the volume's actual print year rather than a
        // coverage-range value that may be indexed in the bundled manifest
        // (mirrors CitationPopoverView.loadPublicationYear on macOS).
        Task {
            await vm.loadPublicationYear(from: url)
        }
        Task {
            await vm.load(volumeURL: url)
            if vm.renderModel != nil {
                vm.recordReadingHistory(projectId: appState.activeProjectId, in: modelContext)
                vm.loadSummaries(context: modelContext)
                vm.refreshCrossProjectNoteCount(
                    activeProjectId: appState.activeProjectId, context: modelContext
                )
                // Adjacent-document lookup powers the Read-mode edge-tap "page-turn"
                // gesture (documentEdgeNavigationOverlay). Loaded unconditionally —
                // the overlay itself is hidden in Research mode and at volume boundaries.
                await vm.loadAdjacentEntries(pipeline: appState.indexingPipeline)
            }
        }
    }

    // MARK: - Loaded View

    @ViewBuilder
    private func loadedView(vm: DocumentViewModel) -> some View {
        if vm.isLoading {
            ProgressView(String(localized: "document.loading", defaultValue: "Loading document…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.loadError {
            ContentUnavailableView(
                String(localized: "document.error.title", defaultValue: "Failed to Load"),
                systemImage: "exclamationmark.triangle",
                description: Text(err.localizedDescription)
            )
        } else if let model = vm.renderModel {
            documentContent(vm: vm, model: model)
        } else {
            // No model yet and no error — volume may not be downloaded, or the
            // initial render frame before bootstrapViewModel() fires. Show a spinner
            // so the view never appears completely blank to the user.
            ProgressView(String(localized: "document.initializing",
                                defaultValue: "Opening document…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Document Content

    @ViewBuilder
    private func documentContent(vm: DocumentViewModel, model: FRUSDocumentRenderModel) -> some View {
        webKitDocumentContent(vm: vm, model: model)
            .toolbar { documentToolbar(vm: vm) }
        // Summarization failures must be visible even when the research panel is
        // hidden (Read mode) — previously they were logged and silently dropped.
        .alert(
            String(localized: "summary.error.title", defaultValue: "Summarization Failed"),
            isPresented: Binding(
                get: { vm.summarizationError != nil },
                set: { if !$0 { vm.summarizationError = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { }
        } message: {
            Text(vm.summarizationError ?? "")
        }
        // Single consolidated sheet driven by the DocumentSheet enum (F-024).
        // One .sheet modifier is cheaper than 7 and makes the "only one sheet at a
        // time" constraint explicit in the type system.
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .personDetail(let person):
                PersonDetailSheet(
                    person: person,
                    mentionCount: vm.selectedPersonMentionCount,
                    onFindAllMentions: {
                        activeSheet = nil
                        appState.pendingSearch = SearchParameters(personRef: person.ref)
                    }
                )
            case .glossDetail(let gloss):
                GlossDetailSheet(gloss: gloss)
            case .citation:
                CitationSheetView(vm: vm)
            case .noteEditor:
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    indexingPipeline: appState.indexingPipeline
                )
            case .noteEditorForHighlight(let hlId):
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    linkedHighlightId: hlId,
                    indexingPipeline: appState.indexingPipeline
                )
            case .editNote(let note):
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    noteToEdit: note,
                    indexingPipeline: appState.indexingPipeline
                )
            case .crossReferenceGraph:
                if let store = appState.crossReferenceStore {
                    CrossReferenceGraphView(
                        entry: entry,
                        crossReferenceStore: store,
                        downloadedVolumeIds: downloadedVolumeIds
                    )
                    // The graph benefits from extra vertical room — large layouts and
                    // the force-directed simulation are easier to read at full height.
                    // Opens at .large (Session 161: a half-height canvas was the
                    // weakest first impression of the feature); the user can still
                    // drag down to .medium as a system gesture.
                    .presentationDetents([.medium, .large], selection: $graphSheetDetent)
                }
            case .summarizePromptPicker:
                SummarizationPromptPickerSheet(
                    vm: vm,
                    service: appState.summarizationService,
                    activeProjectId: appState.activeProjectId
                )
            case .sourceExplorer(let note):
                SourceExplorerView(
                    rawSourceNote: note,
                    documentYear: Self.extractYear(from: entry.dateline),
                    indexingPipeline: appState.indexingPipeline,
                    onRelatedDocumentTapped: { [self] vid, did in
                        handleCrossRefTap(target: did, targetVolumeId: vid)
                    },
                    documentHeader: entry.header,
                    documentDateline: entry.dateline,
                    documentVolumeId: entry.volumeId,
                    documentId: entry.documentId
                )
            case .tagPicker:
                TagPickerSheetView(
                    entry: entry,
                    indexingPipeline: appState.indexingPipeline,
                    initialTagIds: Set(documentTagAssignments.map(\.tagId))
                )
            case .addToCollection:
                CollectionPickerSheetView(entry: entry)
            case .personNotFound:
                personNotFoundSheet
            case .glossNotFound:
                glossNotFoundSheet
            case .naraLookup(let text):
                NARACatalogLookupView(initialText: text)
            }
        }
        .sheet(isPresented: $showHighlightColorPicker) {
            highlightColorPickerSheet
        }
        .confirmationDialog(
            String(localized: "highlight.delete.title", defaultValue: "Remove Highlight"),
            isPresented: Binding(
                get:  { highlightToDelete != nil },
                set:  { if !$0 { highlightToDelete = nil } }
            ),
            titleVisibility: .visible
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
        // Trailing inspector panel for research notes (iPad).
        // On iPhone the toggle button is hidden, so showNotesPanel stays false.
        .inspector(isPresented: $showNotesPanel) {
            notesPanel
        }
        // Load the mention count for the selected person from the FTS index.
        // vm.selectedPerson is set alongside activeSheet so the task id fires correctly.
        .task(id: vm.selectedPerson?.ref) {
            guard let person = vm.selectedPerson else { return }
            await vm.loadPersonMentionCount(for: person)
        }
        // Clear the persisted person selection when any sheet closes so the
        // mention-count task does not re-fire with a stale ref after dismissal.
        // Uses activeSheet?.id (String?) rather than activeSheet directly because
        // DocumentSheet associated-value types (PersonEntry, GlossEntry) are not
        // necessarily Equatable — String? always is.
        .onChange(of: activeSheet?.id) { _, newId in
            if newId == nil { vm.selectedPerson = nil }
        }
        // Handle frusexplorer:// deep-link URLs emitted by FRUSDocumentRenderer's
        // AttributedString rendering path.  Three URL forms are supported:
        //
        //   frusexplorer://doc/{volumeId}/{documentId}
        //     Cross-reference navigation.  volumeId is "_" when the renderer
        //     had no explicit target volume (same volume as current document).
        //
        //   frusexplorer://person/{ref}
        //     Opens the PersonDetailSheet for the persName entry whose xml:id
        //     matches {ref}.  Resolved via vm.personsByRef.
        //
        //   frusexplorer://gloss/{ref}
        //     Opens the GlossDetailSheet for the glossary entry whose xml:id
        //     matches {ref}.  Resolved via vm.termsByRef.
        //
        // SwiftUI routes Text(AttributedString) link taps through this
        // \.openURL environment action on iOS.  On macOS the same routing
        // applies when the frusexplorer:// scheme is registered in Info.plist.
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "frusexplorer" else { return .systemAction }
            let parts = url.pathComponents.filter { $0 != "/" }
            switch url.host {
            case "doc":
                guard parts.count == 2 else { return .systemAction }
                let volComponent = parts[0]
                let docId        = parts[1]
                let targetVol    = volComponent == "_" ? nil : volComponent
                handleCrossRefTap(target: docId, targetVolumeId: targetVol)
                return .handled
            case "person":
                guard let ref = parts.first, !ref.isEmpty else { return .systemAction }
                if let person = vm.personsByRef[ref] {
                    vm.selectedPerson = person
                    activeSheet = .personDetail(person)
                }
                return .handled
            case "gloss":
                guard let ref = parts.first, !ref.isEmpty else { return .systemAction }
                if let gloss = vm.termsByRef[ref] {
                    activeSheet = .glossDetail(gloss)
                }
                return .handled
            default:
                return .systemAction
            }
        })
    }

    private var downloadedVolumeIds: Set<String> {
        guard let dm = appState.downloadManager else { return [] }
        let known = appState.manifestStore.diffResult?.known ?? []
        return Set(known.compactMap { dm.isVolumeDownloaded($0.volumeId) ? $0.volumeId : nil })
    }

    // MARK: - Tool Windows (iPad Stage Manager) / sheet fallback

    /// Shows this document's cross-reference graph. When the platform can open a
    /// second window (Stage Manager on iPad), it opens the `frus.crossReferenceGraph.ios`
    /// scene alongside the document via `appState.currentGraphEntry`; otherwise it
    /// presents the in-place sheet so the graph is reachable on every device.
    private func openCrossReferenceGraph() {
        // The user found the feature — retire its discovery tip.
        ExploreCrossReferencesTip().invalidate(reason: .actionPerformed)
        if supportsMultipleWindows {
            appState.currentGraphEntry = entry
            openWindow(id: "frus.crossReferenceGraph.ios")
        } else {
            activeSheet = .crossReferenceGraph
        }
    }

    /// Resolves this document's source note in the Source Explorer. Opens the
    /// `frus.sourceExplorer.ios` window alongside the document when multi-window is
    /// available (priming `appState.currentSourceNote`/`currentSourceNoteYear`, the
    /// same state the window scene reads), otherwise the in-place sheet.
    private func openSourceExplorer(vm: DocumentViewModel) {
        if supportsMultipleWindows {
            appState.currentSourceNote = vm.sourceNote ?? ""
            appState.currentSourceNoteYear = Self.extractYear(from: entry.dateline)
            appState.currentSourceNoteHeader = entry.header
            appState.currentSourceNoteDateline = entry.dateline
            appState.currentSourceNoteVolumeId = entry.volumeId
            appState.currentSourceNoteDocumentId = entry.documentId
            openWindow(id: "frus.sourceExplorer.ios")
        } else {
            activeSheet = .sourceExplorer(vm.sourceNote ?? "")
        }
    }

    // MARK: - Tag Helpers

    private var appliedUserTags: [UserTag] {
        let assignedIds = Set(documentTagAssignments.map(\.tagId))
        return allUserTags.filter { assignedIds.contains($0.id) }
    }

    private func removeUserTag(_ tag: UserTag) {
        let vId = entry.volumeId
        let dId = entry.documentId
        // Capture remaining IDs before deleting so the FTS5 string is correct.
        let remaining = documentTagAssignments
            .filter { $0.tagId != tag.id }
            .map { $0.tagId.uuidString }
        let tagString: String? = remaining.isEmpty ? nil : remaining.joined(separator: " ")
        for assignment in documentTagAssignments where assignment.tagId == tag.id {
            modelContext.delete(assignment)
        }
        try? modelContext.save()
        guard let pipeline = appState.indexingPipeline else { return }
        Task.detached(priority: .utility) {
            try? await pipeline.updateUserTagIds(volumeId: vId, documentId: dId, userTagIds: tagString)
        }
    }

    // MARK: - Document Year Extraction

    /// Extracts a 4-digit year from a dateline string such as
    /// "Washington, January 15, 1946" or "Moscow, April 3, 1963".
    /// Returns `nil` when no plausible year is found.
    static func extractYear(from dateline: String?) -> Int? {
        guard let dl = dateline else { return nil }
        let pattern = #"\b(19[0-9]{2}|20[0-2][0-9])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: dl, range: NSRange(dl.startIndex..., in: dl)),
              let range = Range(match.range(at: 1), in: dl)
        else { return nil }
        return Int(dl[range])
    }

    // MARK: - Cross-Reference Navigation

    /// Resolves a cross-reference `<ref>` tap to document navigation.
    ///
    /// Extracts the document ID from `target` (strips a leading `#` or takes the
    /// fragment after `#`). Determines the target volume from `targetVolumeId` if
    /// provided, otherwise falls back to the current document's volume.
    ///
    /// If the target volume is not downloaded, falls back to the cross-reference
    /// graph sheet (`showGraph = true`). Otherwise:
    /// - **iOS**: sets `appState.activeTab = .browse` so the Browse tab comes to
    ///   the foreground, then writes `appState.pendingBrowseDocument`.
    /// - **macOS**: writes `appState.pendingBrowseDocument` directly.
    ///
    /// `BrowserView.onChange(of: appState.pendingBrowseDocument)` observes the write
    /// and appends the entry to the navigation stack/split-view path.
    ///
    /// The `DocumentBrowserEntry` is constructed with an empty `header` because the
    /// document title is not known until the XML is parsed. `DocumentView` repopulates
    /// the navigation title from the AST on load — the placeholder is visible only
    /// during the push animation.
    ///
    /// Version history:
    ///   1.0 — Session 44: initial implementation
    /// Routes a tapped in-document cross-reference through
    /// `FRUSURLSchemeHandler.resolveCrossRefTarget` (Session 162): documents
    /// navigate (footnote-suffixed ids resolve to their base document), printed
    /// pages resolve via `PageRangeStore`, and absolute URLs open externally.
    private func handleCrossRefTap(target: String, targetVolumeId: String?) {
        switch FRUSURLSchemeHandler.resolveCrossRefTarget(target, volumeId: targetVolumeId) {
        case .document(let volumeId, let documentId):
            navigateToCrossRef(documentId: documentId, volumeId: volumeId ?? entry.volumeId)

        case .page(let volumeId, let page):
            resolvePageReference(page: page, volumeId: volumeId ?? entry.volumeId)

        case .external(let url):
            openURL(url)

        case .unresolved:
            #if DEBUG
            print("[DocumentView] Cross-ref skipped (unresolvable target): \(target)")
            #endif
        }
    }

    /// Opens `documentId` in `volumeId`, or the cross-reference graph when the
    /// volume isn't downloaded.
    private func navigateToCrossRef(documentId: String, volumeId: String) {
        guard !documentId.isEmpty else { return }
        guard let dm = appState.downloadManager, dm.isVolumeDownloaded(volumeId) else {
            activeSheet = .crossReferenceGraph
            #if DEBUG
            print("[DocumentView] Cross-ref: \(volumeId) not downloaded, opening graph")
            #endif
            return
        }

        let crossEntry = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            documentNumber: nil,
            // Use documentId as a non-empty placeholder so the breadcrumb label is
            // visible while the document loads. DocumentView replaces the navigation
            // title with vm.documentTitle once the XML has been parsed.
            header: documentId,
            dateline: nil,
            sourceNote: nil
        )
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        appState.pendingBrowseDocument = crossEntry

        #if DEBUG
        print("[DocumentView] Cross-ref tap → \(volumeId)/\(documentId)")
        #endif
    }

    /// Resolves a printed-page reference to its containing document and opens it.
    private func resolvePageReference(page: Int, volumeId: String) {
        guard let store = appState.pageRangeStore else {
            #if DEBUG
            print("[DocumentView] Page ref: PageRangeStore unavailable")
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
                    print("[DocumentView] Page ref: p. \(page) of \(volumeId) not in page index")
                    #endif
                }
            }
        }
    }

    // MARK: - Toolbar

    /// Document toolbar.
    ///
    /// ## Layout — single flat `ToolbarItemGroup`, no app-owned overflow menu
    /// Every action (Add Note, Tag, Highlight, Read/Research toggle, View/Copy/
    /// Share Citation, Add to Collection, Cross-References, NARA Lookup, Source
    /// Explorer, Open in New Window, Summarize) is placed directly in one
    /// `ToolbarItemGroup(placement: .primaryAction)`.
    ///
    /// On iPhone, when these don't all fit the navigation bar, UIKit/SwiftUI
    /// automatically collapses the overflow behind its own "···" button and
    /// presents the remaining actions as a single flat list — one tap reveals
    /// every tool. Previously the app *also* wrapped the long tail of actions
    /// in its own "More" `Menu`, so the system's "···" → our "More" → tools
    /// produced a wasted, confusing extra hierarchy level. Removing the
    /// wrapper lets the system overflow serve as the one and only "···" menu
    /// (Session 2026-06-07).
    ///
    /// "Share Citation" (added Session 2026-06-07) presents the system share
    /// sheet via `ShareLink` with a single message combining the formatted
    /// citation and the document's canonical `history.state.gov` URL — see
    /// `DocumentViewModel.shareableCitationMessage`.
    @ToolbarContentBuilder
    private func documentToolbar(vm: DocumentViewModel) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {

            // 1. Add research note
            Button {
                activeSheet = .noteEditor
            } label: {
                Label(
                    String(localized: "document.toolbar.addNote", defaultValue: "Add Research Note"),
                    systemImage: "note.text.badge.plus"
                )
            }
            .controlHelp(
                String(localized: "document.toolbar.addNote.a11y", defaultValue: "Add research note"),
                detail: String(localized: "document.toolbar.addNote.help",
                               defaultValue: "Write a research note attached to this document"),
                systemImage: "note.text.badge.plus"
            )

            // 2. Tag document
            Button {
                activeSheet = .tagPicker
            } label: {
                Label(
                    String(localized: "document.toolbar.addTag", defaultValue: "Tag Document"),
                    systemImage: "tag"
                )
            }
            .controlHelp(
                String(localized: "document.toolbar.addTag.a11y", defaultValue: "Tag document"),
                detail: String(localized: "document.toolbar.addTag.help",
                               defaultValue: "Apply your subject tags to this document"),
                systemImage: "tag"
            )

            // 3. Create highlight — enabled when text is selected in the web view
            Button {
                showHighlightColorPicker = true
            } label: {
                Image(systemName: "paintbrush.pointed")
            }
            .disabled(webKitSelectionRange == nil)
            .controlHelp(
                String(localized: "document.toolbar.createHighlight.a11y",
                       defaultValue: "Create highlight"),
                detail: String(localized: "document.toolbar.createHighlight.help",
                               defaultValue: "Highlight the selected passage — select text in the document first"),
                systemImage: "paintbrush.pointed"
            )
            // The colour-picker sheet is presented from the main content chain
            // (single `.sheet(isPresented:)` for this binding) so it works for
            // both this button and the selection edit-menu action, including
            // when this button is collapsed into the system overflow menu.

            // 3b. Add Note to Highlight — transient, appears right after a
            // highlight is created (mirrors the macOS research strip button).
            // One-shot: consumed on tap, cleared on document change.
            if let highlightId = pendingHighlightLink {
                Button {
                    pendingHighlightLink = nil
                    activeSheet = .noteEditorForHighlight(highlightId)
                } label: {
                    Label(
                        String(localized: "document.toolbar.noteForHighlight",
                               defaultValue: "Add Note to Highlight"),
                        systemImage: "note.text.badge.plus"
                    )
                }
                .controlHelp(
                    String(localized: "document.toolbar.noteForHighlight",
                           defaultValue: "Add Note to Highlight"),
                    detail: String(localized: "document.toolbar.noteForHighlight.a11y",
                                   defaultValue: "Add a research note to the highlight you just created"),
                    systemImage: "note.text.badge.plus"
                )
            }

            // 4. Research panel toggle — segmented Read / Research picker.
            // Binding wraps the AppStorage Bool so the layout transition can be
            // animated; the segmented control's own selection animation handles the
            // visual state change without an additional withAnimation call.
            Picker(
                String(localized: "document.toolbar.panelMode",
                       defaultValue: "View mode"),
                selection: Binding(
                    get: { panelVisible },
                    set: { newVal in
                        withAnimation(.easeInOut(duration: 0.2)) { panelVisible = newVal }
                    }
                )
            ) {
                Text(String(localized: "document.toolbar.panelMode.read",
                            defaultValue: "Read"))
                    .tag(false)
                Text(String(localized: "document.toolbar.panelMode.research",
                            defaultValue: "Research"))
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel(
                String(localized: "document.toolbar.panelMode.a11y",
                       defaultValue: "Toggle reading or research view")
            )
            .accessibilityHint(
                String(localized: "document.toolbar.panelMode.hint",
                       defaultValue: "Read mode also enables edge-tap navigation to the previous and next document in this volume")
            )

            // 5. View Citation
            Button {
                activeSheet = .citation
            } label: {
                Label(
                    String(localized: "document.toolbar.viewCitation", defaultValue: "View Citation"),
                    systemImage: "doc.text"
                )
            }
            .disabled(vm.formattedCitation == nil)
            .controlHelp(
                String(localized: "document.toolbar.viewCitation", defaultValue: "View Citation"),
                detail: String(localized: "document.toolbar.viewCitation.help",
                               defaultValue: "Show the formatted citation for this document"),
                systemImage: "doc.text"
            )

            // 6. Copy Citation — uses plain text so _..._ italic markers are
            // not pasted as raw underscores. View Citation (above) still uses
            // the markdown string via CitationSheetView.attributedCitation.
            Button {
                if let citation = vm.plainTextFormattedCitation {
                    copyToPasteboard(citation)
                }
            } label: {
                Label(
                    String(localized: "document.toolbar.copyCitation", defaultValue: "Copy Citation"),
                    systemImage: "doc.on.clipboard"
                )
            }
            .disabled(vm.plainTextFormattedCitation == nil)
            .controlHelp(
                String(localized: "document.toolbar.copyCitation", defaultValue: "Copy Citation"),
                detail: String(localized: "document.toolbar.copyCitation.help",
                               defaultValue: "Copy the formatted citation to the clipboard"),
                systemImage: "doc.on.clipboard"
            )

            // 6b. Share Citation — system share sheet with the formatted citation
            // and the canonical history.state.gov URL combined into one message.
            ShareLink(item: vm.shareableCitationMessage ?? "") {
                Label(
                    String(localized: "document.toolbar.shareCitation", defaultValue: "Share Citation"),
                    systemImage: "square.and.arrow.up"
                )
            }
            .disabled(vm.shareableCitationMessage == nil)
            .controlHelp(
                String(localized: "document.toolbar.shareCitation", defaultValue: "Share Citation"),
                detail: String(localized: "document.toolbar.shareCitation.help",
                               defaultValue: "Share the citation and a link to this document on history.state.gov"),
                systemImage: "square.and.arrow.up"
            )

            // 7. Add to Collection
            Button {
                activeSheet = .addToCollection
            } label: {
                Label(
                    String(localized: "document.toolbar.addToCollection",
                           defaultValue: "Add to Collection"),
                    systemImage: "folder.badge.plus"
                )
            }
            .controlHelp(
                String(localized: "document.toolbar.addToCollection.a11y",
                       defaultValue: "Add document to a collection"),
                detail: String(localized: "document.toolbar.addToCollection.help",
                               defaultValue: "Add this document to a new or existing collection"),
                systemImage: "folder.badge.plus"
            )

            // 8. Cross-references — opens alongside the document as a Stage Manager
            // window when multi-window is available, otherwise an in-place sheet.
            Button {
                openCrossReferenceGraph()
            } label: {
                Label(
                    String(localized: "document.toolbar.crossRef", defaultValue: "Cross-References"),
                    systemImage: "arrow.triangle.branch"
                )
            }
            .controlHelp(
                String(localized: "document.toolbar.crossRef", defaultValue: "Cross-References"),
                detail: String(localized: "document.toolbar.crossRef.help",
                               defaultValue: "Explore the documents this one cites and the documents that cite it, on a timeline"),
                systemImage: "arrow.triangle.branch"
            )
            .popoverTip(ExploreCrossReferencesTip())

            // 9. NARA Catalog Lookup moved to the text-selection edit menu
            // (see .onEditMenuNARALookup on the web view) — the conditional
            // toolbar item popped in and out of the overflow menu as the
            // selection changed, which was both jarring and undiscoverable.

            // 10. Source Explorer — always available for all documents. Opens
            // alongside the document as a Stage Manager window when multi-window is
            // available (the frus.sourceExplorer.ios scene), otherwise an in-place
            // sheet — so it works for every iPad regardless of Stage Manager.
            Button {
                openSourceExplorer(vm: vm)
            } label: {
                Label(
                    String(localized: "document.toolbar.sourceExplorer",
                           defaultValue: "Source Explorer"),
                    systemImage: "archivebox"
                )
            }
            .controlHelp(
                String(localized: "document.toolbar.sourceExplorer",
                       defaultValue: "Source Explorer"),
                detail: String(localized: "document.toolbar.sourceExplorer.help",
                               defaultValue: "Trace this document's archival source in the National Archives catalog"),
                systemImage: "archivebox"
            )

            // 11. Open in New Window — only when the platform can actually open a
            // second window (Stage Manager on iPad). Gating on supportsMultipleWindows
            // instead of sizeClass == .regular stops the button from appearing on
            // every iPad and then doing nothing when Stage Manager is off.
            if supportsMultipleWindows {
                Button {
                    openWindow(value: DocumentWindowID(
                        volumeId: entry.volumeId,
                        documentId: entry.documentId,
                        header: vm.documentTitle ?? entry.header
                    ))
                } label: {
                    Label(
                        String(localized: "document.toolbar.openInNewWindow",
                               defaultValue: "Open in New Window"),
                        systemImage: "square.on.square"
                    )
                }
                .controlHelp(
                    String(localized: "document.toolbar.openInNewWindow",
                           defaultValue: "Open in New Window"),
                    detail: String(localized: "document.toolbar.openInNewWindow.help",
                                   defaultValue: "Open this document in a separate window alongside the current one"),
                    systemImage: "square.on.square"
                )
            }

            // 12. Summarize — only when Apple Intelligence is available
            if appState.summarizationService != nil
                && AppleIntelligenceProvider.shared.isAvailable {
                Button {
                    activeSheet = .summarizePromptPicker
                } label: {
                    if vm.isSummarizing {
                        Label(
                            String(localized: "document.toolbar.summarizing",
                                   defaultValue: "Summarizing…"),
                            systemImage: "sparkles"
                        )
                    } else {
                        Label(
                            String(localized: "document.toolbar.summarize",
                                   defaultValue: "Summarize with AI"),
                            systemImage: "sparkles"
                        )
                    }
                }
                .disabled(vm.isSummarizing || vm.documentPlainText.isEmpty)
                .controlHelp(
                    String(localized: "document.toolbar.summarize",
                           defaultValue: "Summarize with AI"),
                    detail: String(localized: "document.toolbar.summarize.help",
                                   defaultValue: "Generate an on-device summary of this document with Apple Intelligence"),
                    systemImage: "sparkles"
                )
            }
        }
        // Notes panel toggle — leading nav bar position on iPad
        if sizeClass == .regular {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showNotesPanel.toggle()
                } label: {
                    Image(systemName: "note.text")
                        .foregroundStyle(showNotesPanel ? Color.accentColor : Color.primary)
                }
                .controlHelp(
                    showNotesPanel
                        ? String(localized: "document.toolbar.notesPanel.hide.a11y",
                                 defaultValue: "Hide notes panel")
                        : String(localized: "document.toolbar.notesPanel.show.a11y",
                                 defaultValue: "Show notes panel"),
                    detail: String(localized: "document.toolbar.notesPanel.help",
                                   defaultValue: "Show or hide the research notes panel beside the document"),
                    systemImage: "note.text"
                )
            }
        }
    }

    // MARK: - Stale Highlight Banner

    private var staleHighlightBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(String(localized: "highlight.stale.warning",
                        defaultValue: "Some highlights may be misaligned — the document has been updated since they were created."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
    }

    // MARK: - Person / Gloss Not Found Sheets

    /// Shown when a persName link is tapped but the person data isn't in the index.
    /// This happens when a volume hasn't been indexed yet, or when the index was built
    /// before the Session 130 parser fix that correctly reads `xml:id` from persons lists.
    /// The sheet provides actionable guidance (re-index the volume) rather than silently
    /// doing nothing.
    private var personNotFoundSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(String(localized: "personNotFound.title",
                            defaultValue: "Person Information Unavailable"))
                    .font(.headline)
                Text(String(localized: "personNotFound.detail",
                            defaultValue: "Detailed information about this person isn't available for this volume. To populate person data, re-index the volume in Settings → Volumes."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle(String(localized: "personNotFound.navTitle",
                                    defaultValue: "Person"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "personNotFound.dismiss",
                                  defaultValue: "Done")) {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// Shown when a gloss link is tapped but the term data isn't in the index.
    private var glossNotFoundSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(String(localized: "glossNotFound.title",
                            defaultValue: "Term Definition Unavailable"))
                    .font(.headline)
                Text(String(localized: "glossNotFound.detail",
                            defaultValue: "A definition for this term isn't available for this volume. To populate term data, re-index the volume in Settings → Volumes."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle(String(localized: "glossNotFound.navTitle",
                                    defaultValue: "Term"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "glossNotFound.dismiss",
                                  defaultValue: "Done")) {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - WebKit document content (Session 142+)

    /// Document view for the WebKit rendering path (`FeatureFlags.useWebKitRenderer == true`).
    ///
    /// `WKWebView` handles all scrolling and footnote display (HTML Popover API).
    /// Header items (summary strip, editorial badge, highlights banner) are pinned
    /// above the web view. `DocumentTagSection` and volume navigation are omitted
    /// from this path until Session 147 finalises the WebKit migration.
    @ViewBuilder
    private func webKitDocumentContent(
        vm: DocumentViewModel,
        model: FRUSDocumentRenderModel
    ) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            // Non-scrollable header
            if let summary = vm.activeSummary {
                SummaryStripView(vm: vm, summary: summary, totalCount: vm.summaries.count)
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.top, 12)
                Divider()
            }
            if entry.isEditorialNote {
                EditorialNoteBadge()
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            // Stale highlight banner — shown when any stored highlight's
            // renderingVersion doesn't match the current document version.
            let renderingVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
            if highlights.contains(where: { $0.renderingVersion != renderingVersion }) {
                staleHighlightBanner
            }

            // Document body — WKWebView handles scrolling, footnotes, and highlights.
            // The edge-tap navigation overlay is layered on top via ZStack rather than
            // composed as a sibling, so it can float over the web view without
            // participating in its layout or scrolling.
            ZStack {
            FRUSDocumentWebView(
                model: model,
                onPersonTap: { person in
                    vm.selectedPerson = person
                    if let person {
                        activeSheet = .personDetail(person)
                    } else {
                        // Lookup failed — persons not yet indexed for this volume,
                        // or the person ref doesn't match any entry in the index.
                        activeSheet = .personNotFound
                    }
                },
                onGlossTap: { entry in
                    if let entry {
                        activeSheet = .glossDetail(entry)
                    } else {
                        activeSheet = .glossNotFound
                    }
                },
                onCrossRefTap: { target, targetVolumeId in
                    handleCrossRefTap(target: target, targetVolumeId: targetVolumeId)
                }
            )
            .highlights(highlights)
            .onSelectionChanged { start, end, text in
                if start >= 0 {
                    // In-document selection with valid offsets — enables highlights + lookup.
                    webKitSelectionRange = (start, end)
                } else {
                    // Footnote / out-of-document selection — text only, no valid offsets.
                    // Clear the range so highlight creation is not offered, but keep the
                    // text so NARA lookup remains available.
                    webKitSelectionRange = nil
                }
                webKitSelectedText = text.isEmpty ? nil : text
            }
            .onSelectionCleared {
                // Only clear the offset range. webKitSelectedText is intentionally
                // preserved so the NARA lookup button stays available after the selection
                // is released (e.g. when the user opens the More menu on iOS, which causes
                // the WebView to blur and fire a false selectioncleared event).
                // webKitSelectedText is cleared when the NARA lookup button is tapped.
                webKitSelectionRange = nil
            }
            .onHighlightTapped  { start, end in highlightToDelete = (start, end) }
            .onEditMenuHighlight {
                // "Highlight" on the selection edit menu — same flow as the
                // toolbar paintbrush: pick a colour, then create the highlight
                // from webKitSelectionRange.
                showHighlightColorPicker = true
            }
            .onEditMenuNARALookup {
                let text = webKitSelectedText ?? ""
                webKitSelectedText = nil
                activeSheet = .naraLookup(text: text)
            }
            .canHighlightSelection { webKitSelectionRange != nil }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            documentEdgeNavigationOverlay(vm: vm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Research panel — accordion of Notes, Tags, Summary
            if panelVisible {
                Divider()
                iOSResearchPanel(vm: vm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Edge-Tap Document Navigation (Read mode "page-turn")

    /// Invisible leading/trailing edge-tap zones that navigate to the previous/next
    /// document in the current volume — an ebook-reader-style "page-turn" gesture.
    ///
    /// Shown only when:
    ///  - **The user has not disabled it** (`edgeTapNavigationEnabled`,
    ///    `SettingsKeys.edgeTapNavigationEnabled`, default on). Some readers
    ///    trigger the zones accidentally; this is an escape hatch (Session 154).
    ///  - **Read mode is active** (`!panelVisible` — the "Read"/"Research" segmented
    ///    control in the toolbar; see `documentToolbar`). Research mode hides the
    ///    zones entirely so taps near the edges while annotating, selecting text, or
    ///    using the research panel are never misread as page-turns.
    ///  - **An adjacent document exists** in that direction (`vm.previousEntry`/
    ///    `vm.nextEntry`, populated by `DocumentViewModel.loadAdjacentEntries`).
    ///    No zone is shown at the first/last document of a volume.
    ///
    /// Each zone is a narrow, fully transparent strip pinned to its edge —
    /// `FRUSTheme.documentEdgeTapZoneWidth` is chosen to sit mostly outside the
    /// reading column (which begins at `documentHorizontalPadding`), minimising
    /// overlap with inline `<persName>`/`<gloss>`/cross-reference links so WKWebView
    /// still receives taps on in-column content. A `Spacer` between the two zones
    /// guarantees the entire central reading area is never intercepted.
    ///
    /// Version history:
    ///   1.0 — Session 2026-06-07: initial implementation
    ///   1.1 — Session 154: gated on `edgeTapNavigationEnabled` preference
    @ViewBuilder
    private func documentEdgeNavigationOverlay(vm: DocumentViewModel) -> some View {
        if !panelVisible && edgeTapNavigationEnabled {
            HStack(spacing: 0) {
                documentEdgeTapZone(
                    adjacentEntry: vm.previousEntry,
                    systemImage: "chevron.left",
                    label: String(localized: "document.nav.previous.a11y",
                                  defaultValue: "Previous document"),
                    hint: String(localized: "document.nav.previous.hint",
                                 defaultValue: "Opens the previous document in this volume")
                )
                Spacer(minLength: 0)
                documentEdgeTapZone(
                    adjacentEntry: vm.nextEntry,
                    systemImage: "chevron.right",
                    label: String(localized: "document.nav.next.a11y",
                                  defaultValue: "Next document"),
                    hint: String(localized: "document.nav.next.hint",
                                 defaultValue: "Opens the next document in this volume")
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Let the zones themselves opt into hit-testing; the HStack/Spacer must
            // not swallow taps meant for the web view's central reading column.
            .allowsHitTesting(true)
        }
    }

    /// A single transparent edge-tap zone. Renders nothing (and accepts no taps)
    /// when `adjacentEntry` is `nil`, so volume boundaries show no dead tap area.
    @ViewBuilder
    private func documentEdgeTapZone(
        adjacentEntry: DocumentBrowserEntry?,
        systemImage: String,
        label: String,
        hint: String
    ) -> some View {
        if let adjacentEntry {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: FRUSTheme.documentEdgeTapZoneWidth)
                .onTapGesture {
                    navigateToAdjacentDocument(adjacentEntry)
                }
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityHint(hint)
                .accessibilityAddTraits(.isButton)
                #if DEBUG
                // Visualise the otherwise-invisible tap zones during development.
                // FRUS_DEBUG_EDGE_TAP_ZONES is unset by default — set it in the
                // scheme's environment variables to enable the overlay tint.
                .overlay {
                    if ProcessInfo.processInfo.environment["FRUS_DEBUG_EDGE_TAP_ZONES"] != nil {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                            .background(Color.accentColor.opacity(0.08))
                    }
                }
                #endif
        } else {
            Color.clear
                .frame(width: FRUSTheme.documentEdgeTapZoneWidth)
                .allowsHitTesting(false)
        }
    }

    /// Navigates to a sibling document within the same volume, triggered by the
    /// edge-tap "page-turn" gesture.
    ///
    /// Reuses the same cross-reference navigation pathway as `handleCrossRefTap`
    /// (`appState.pendingBrowseDocument`, observed by `BrowserView.onChange` which
    /// appends the entry to the Browse tab's navigation stack) — the identical
    /// mechanism `MacDocumentView`'s prev/next chevron buttons use on macOS
    /// (`navigationPath.append(prev/next)`). `DocumentView` can be presented from
    /// several navigation contexts (Search, Citation Lookup, Cross-Reference Graph,
    /// Browse), so routing every document-to-document jump through the Browse tab
    /// keeps behaviour predictable and consistent with existing in-document navigation.
    private func navigateToAdjacentDocument(_ adjacent: DocumentBrowserEntry) {
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        appState.pendingBrowseDocument = adjacent
        #if DEBUG
        print("[DocumentView] Edge-tap page-turn → \(adjacent.volumeId)/\(adjacent.documentId)")
        #endif
    }

    // MARK: - iOS Research Panel

    @ViewBuilder
    private func iOSResearchPanel(vm: DocumentViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            // ── Summary ────────────────────────────────────────────────────────
            if appState.summarizationService != nil || vm.activeSummary != nil {
                iOSPanelSectionHeader(
                    title: String(localized: "panel.summary.title", defaultValue: "Summary"),
                    badge: nil,
                    isExpanded: $summaryExpanded
                )
                if summaryExpanded, let summary = vm.activeSummary {
                    Divider()
                    SummaryStripView(vm: vm, summary: summary, totalCount: vm.summaries.count)
                        .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                        .padding(.vertical, 8)
                } else if summaryExpanded {
                    Divider()
                    if vm.isSummarizing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(String(localized: "panel.summary.generating",
                                        defaultValue: "Summarizing…"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    } else if AppleIntelligenceProvider.shared.isAvailable {
                        Button {
                            activeSheet = .summarizePromptPicker
                        } label: {
                            Label(
                                String(localized: "panel.summary.generate",
                                       defaultValue: "Summarize this Document"),
                                systemImage: "sparkles"
                            )
                            .font(.callout)
                        }
                        .buttonStyle(.borderless)
                        .disabled(vm.documentPlainText.isEmpty)
                        .padding(16)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(.tertiary)
                            Text(String(localized: "panel.summary.unavailable",
                                        defaultValue: "Apple Intelligence is not available on this device, so new summaries cannot be generated. Summaries from your other devices still appear here via iCloud."))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                }
                Divider()
            }

            // ── Notes ─────────────────────────────────────────────────────────
            iOSPanelSectionHeader(
                title: String(localized: "panel.notes.title", defaultValue: "Notes"),
                badge: documentNotes.isEmpty ? nil : "\(documentNotes.count)",
                isExpanded: $notesExpanded
            )
            if notesExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(documentNotes) { note in
                        Button { activeSheet = .editNote(note) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.bodyText.isEmpty
                                     ? String(localized: "panel.notes.emptyNote", defaultValue: "Empty note")
                                     : note.bodyText)
                                    .font(.callout)
                                    .foregroundStyle(note.bodyText.isEmpty ? .tertiary : .primary)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(note.lastModified ?? .now, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    Button {
                        activeSheet = .noteEditor
                    } label: {
                        Label(
                            String(localized: "panel.notes.add", defaultValue: "Add Note"),
                            systemImage: "plus.circle"
                        )
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                    .padding(.vertical, 10)
                }
            }
            Divider()

            // ── Tags ───────────────────────────────────────────────────────────
            let appliedTags = appliedUserTags
            iOSPanelSectionHeader(
                title: String(localized: "panel.tags.title", defaultValue: "Tags"),
                badge: appliedTags.isEmpty ? nil : "\(appliedTags.count)",
                isExpanded: $tagsExpanded
            )
            if tagsExpanded {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appliedTags) { tag in
                            FRUSTagChip(label: tag.name, style: .user) {
                                removeUserTag(tag)
                            }
                        }
                        Button {
                            activeSheet = .tagPicker
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                if appliedTags.isEmpty {
                                    Text(String(localized: "panel.tags.add",
                                                defaultValue: "Add Tag"))
                                }
                            }
                            .font(.system(size: FRUSTheme.captionSize, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, FRUSTheme.tagPaddingV)
                            .background(Color.accentColor.opacity(0.10))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func iOSPanelSectionHeader(
        title: String,
        badge: String?,
        isExpanded: Binding<Bool>
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlight Actions

    /// Deletes the `DocumentHighlight` matching `startOffset`/`endOffset` from SwiftData.
    @MainActor
    private func deleteHighlight(startOffset: Int, endOffset: Int) {
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
        print("[DocumentView] Deleted highlight [\(startOffset)–\(endOffset)] from \(did)")
        #endif
    }

    @MainActor
    private func createHighlight(color: DocumentHighlight.Color) {
        guard let range = webKitSelectionRange,
              let model = vm?.renderModel else { return }
        let rv = ASTToRenderNodeConverter.renderingVersion(for: model)
        let flat = buildFlatText(from: model)
        let selectedText: String
        if let r = Range(NSRange(location: range.0, length: range.1 - range.0), in: flat) {
            selectedText = String(flat[r])
        } else {
            selectedText = ""
        }
        let highlight = DocumentHighlight(
            volumeId:         entry.volumeId,
            documentId:       entry.documentId,
            startOffset:      range.0,
            endOffset:        range.1,
            colorTag:         color.rawValue,
            selectedText:     selectedText,
            renderingVersion: rv
        )
        modelContext.insert(highlight)
        webKitSelectionRange = nil
        pendingHighlightLink = highlight.id
    }

    private func swiftUIColor(for color: DocumentHighlight.Color) -> Color {
        switch color {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        }
    }

    // MARK: - Highlight Color Picker Sheet

    private var highlightColorPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(localized: "doc.highlight.pickColor",
                            defaultValue: "Highlight Color"))
                    .font(.headline)
                HStack(spacing: 16) {
                    ForEach(DocumentHighlight.Color.allCases, id: \.rawValue) { color in
                        Button {
                            createHighlight(color: color)
                            showHighlightColorPicker = false
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(swiftUIColor(for: color))
                                    .frame(width: 44, height: 44)
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.rawValue.capitalized)
                    }
                }
            }
            .padding()
            .navigationTitle(String(localized: "doc.highlight.sheet.title",
                                    defaultValue: "Choose Color"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "doc.highlight.sheet.cancel",
                                  defaultValue: "Cancel")) {
                        showHighlightColorPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }

    // MARK: - Clipboard

    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private var notesPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "document.notesPanel.title",
                            defaultValue: "Research Notes"))
                    .font(.headline)
                if !documentNotes.isEmpty {
                    Text("\(documentNotes.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                Spacer()
                Button {
                    activeSheet = .noteEditor
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(
                    String(localized: "document.notesPanel.add.a11y",
                           defaultValue: "Add research note")
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if documentNotes.isEmpty {
                ContentUnavailableView(
                    String(localized: "document.notesPanel.empty.title",
                           defaultValue: "No Notes"),
                    systemImage: "note.text",
                    description: Text(
                        String(localized: "document.notesPanel.empty.detail",
                               defaultValue: "Tap + to add a research note for this document.")
                    )
                )
                .frame(maxHeight: .infinity)
            } else {
                List(documentNotes) { note in
                    Button {
                        activeSheet = .editNote(note)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.bodyText.isEmpty
                                 ? String(localized: "document.notesPanel.emptyNote",
                                          defaultValue: "Empty note")
                                 : note.bodyText)
                                .font(.callout)
                                .foregroundStyle(note.bodyText.isEmpty ? .tertiary : .primary)
                                .lineLimit(4)
                            Text(note.lastModified ?? .now, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        note.bodyText.isEmpty
                            ? String(localized: "document.notesPanel.emptyNote.a11y",
                                     defaultValue: "Empty note")
                            : note.bodyText
                    )
                }
                .listStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - CitationSheetView

/// Displays a formatted citation string in a sheet with Copy/Done actions and
/// an Export menu (BibTeX/RIS copy plus "Send to Zotero" share actions).
///
/// `formattedCitation` wraps the FRUS series title in Markdown italic syntax
/// (`_Foreign Relations of the United States_…`, see
/// `HistoryAtStateCitationFormatter.italicizedTitle`). Plain `Text(String)`
/// does not interpret Markdown for runtime strings, so the underscores would
/// render literally; parsing into an `AttributedString` first renders the
/// series title in actual italics — mirroring `CitationPopoverView` on macOS.
///
/// Version history:
///   1.0 — Session 59: initial implementation
///   1.1 — Session 155: added Export menu (Copy BibTeX/RIS, "Send to Zotero"
///          BibTeX/JSON share actions); takes `vm` instead of a raw string
private struct CitationSheetView: View {
    let vm: DocumentViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var bibtexFileURL: URL?
    @State private var risFileURL: URL?

    private var citation: String {
        vm.formattedCitation ?? ""
    }

    /// The citation parsed as inline Markdown so `_…_` renders as italics;
    /// falls back to the raw string if parsing fails.
    private var attributedCitation: AttributedString {
        (try? AttributedString(
            markdown: citation,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(citation)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(attributedCitation)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    exportMenu
                }
                .padding()
            }
            .navigationTitle(
                String(localized: "document.citation.title", defaultValue: "Citation")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.sheet.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 220)
        #endif
        .task {
            prepareExportFiles()
        }
    }

    // MARK: - Export Menu

    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Button {
                if let bibtex = vm.bibtexCitation {
                    copyToPasteboard(bibtex)
                }
            } label: {
                Label(String(localized: "document.citation.copyBibtex", defaultValue: "Copy BibTeX"), systemImage: "doc.on.clipboard")
            }
            .disabled(vm.bibtexCitation == nil)

            Button {
                if let ris = vm.risCitation {
                    copyToPasteboard(ris)
                }
            } label: {
                Label(String(localized: "document.citation.copyRis", defaultValue: "Copy RIS"), systemImage: "doc.on.clipboard")
            }
            .disabled(vm.risCitation == nil)

            Divider()

            if let bibtexFileURL {
                ShareLink(item: bibtexFileURL) {
                    Label(String(localized: "document.citation.sendZoteroBibtex", defaultValue: "Send to Zotero (BibTeX)…"), systemImage: "square.and.arrow.up")
                }
            }

            if let risFileURL {
                ShareLink(item: risFileURL) {
                    Label(String(localized: "document.citation.sendZoteroRis", defaultValue: "Send to Zotero (RIS)…"), systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Label(String(localized: "document.citation.export", defaultValue: "Export"), systemImage: "square.and.arrow.up.on.square")
        }
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    /// Writes the BibTeX and RIS exports to temporary files for `ShareLink`.
    ///
    /// Both are formats Zotero can import from a shared file. (The previous Zotero-API
    /// JSON envelope is *not* a Zotero file-import format — Zotero reported "couldn't read
    /// payload" — so the second option now shares RIS, which Zotero imports reliably.)
    ///
    /// The RIS file is rendered from the document's Zotero `Item` so it carries the
    /// user's FRUS Explorer tags (→ `KW`) and research notes (→ `N1`), matching the
    /// collection-level Zotero export. BibTeX remains a bibliographic-only citation.
    private func prepareExportFiles() {
        if let bibtex = vm.bibtexCitation {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(vm.entry.volumeId)-\(vm.entry.documentId).bib")
            if (try? bibtex.write(to: url, atomically: true, encoding: .utf8)) != nil {
                bibtexFileURL = url
            }
        }

        let resolved = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: vm.entry.documentId, volumeId: vm.entry.volumeId, context: modelContext)
        if let item = vm.zoteroItem(tags: resolved.tags, notes: resolved.notes) {
            let ris = RISExporter().export(zoteroItem: item)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(vm.entry.volumeId)-\(vm.entry.documentId).ris")
            if (try? ris.write(to: url, atomically: true, encoding: .utf8)) != nil {
                risFileURL = url
            }
        }

        #if DEBUG
        print("[CitationSheetView] export files prepared: bibtex=\(bibtexFileURL != nil), ris=\(risFileURL != nil)")
        #endif
    }
}

// MARK: - SummaryStripView

private struct SummaryStripView: View {
    @Bindable var vm: DocumentViewModel
    let summary: GeneratedSummary
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(
                    String(localized: "document.summary.label", defaultValue: "Summary"),
                    systemImage: "sparkles"
                )
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                Spacer()
                if totalCount > 1 {
                    Button {
                        vm.activeSummaryIndex = (vm.activeSummaryIndex + 1) % totalCount
                    } label: {
                        Text(String(localized: "document.summary.next",
                                    defaultValue: "Next"))
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "document.summary.next.a11y",
                               defaultValue: "View next summary")
                    )
                }
            }
            Text(summary.responseText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            if summary.wasChunked {
                Label(
                    String(localized: "document.summary.chunked",
                           defaultValue: "Summarized in sections"),
                    systemImage: "info.circle"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - SummarizationPromptPickerSheet

private struct SummarizationPromptPickerSheet: View {
    let vm: DocumentViewModel
    let service: SummarizationService?
    let activeProjectId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    var body: some View {
        NavigationStack {
            List {
                ForEach(allPrompts) { prompt in
                    Button {
                        dismiss()
                        guard let service else { return }
                        Task {
                            await vm.generateSummary(
                                prompt: prompt,
                                provider: AppleIntelligenceProvider.shared,
                                service: service,
                                activeProjectId: activeProjectId,
                                context: modelContext
                            )
                        }
                    } label: {
                        PromptPickerRow(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(
                String(localized: "document.summarize.picker.title",
                       defaultValue: "Choose a Prompt")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "document.summarize.picker.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if allPrompts.isEmpty {
                    ContentUnavailableView(
                        String(localized: "document.summarize.picker.empty.title",
                               defaultValue: "No Prompts"),
                        systemImage: "sparkles",
                        description: Text(
                            String(localized: "document.summarize.picker.empty.detail",
                                   defaultValue: "Add a prompt in Settings → Summarization Prompts.")
                        )
                    )
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #else
        .frame(minWidth: 400, minHeight: 340)
        #endif
    }
}

// MARK: - PromptPickerRow

private struct PromptPickerRow: View {
    let prompt: SummarizationPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(prompt.name).font(.body)
                if prompt.isStandard {
                    Text(String(localized: "prompt.picker.row.standard",
                                defaultValue: "Standard"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(formatLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var formatLabel: String {
        switch prompt.responseFormat {
        case .general:
            return String(localized: "prompt.picker.row.format.general",
                          defaultValue: "General prose")
        case .structured(let schema):
            let names = schema.fields.map(\.name).joined(separator: ", ")
            return String(localized: "prompt.picker.row.format.structured",
                          defaultValue: "Structured: \(names)")
        }
    }
}

// DocumentTagSection and DocumentTagChip removed — document-level subject tags
// are no longer shown in the UI. The SubjectTagStore and DocumentViewModel.subjectTags
// remain populated for potential future use; only the display layer is removed.

// MARK: - CrossProjectNoteIndicator

private struct CrossProjectNoteIndicator: View {
    let notes: [ResearchNote]
    let activeProjectId: UUID?
    let onPromote: (ResearchNote) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                    Text("\(notes.count) notes from other projects")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(notes.count) research notes from other projects")
            .accessibilityHint(
                isExpanded
                    ? String(localized: "document.crossProject.collapse.hint",
                             defaultValue: "Collapse")
                    : String(localized: "document.crossProject.expand.hint",
                             defaultValue: "Expand to reveal")
            )

            if isExpanded {
                if activeProjectId != nil {
                    ForEach(notes, id: \.id) { note in
                        CrossProjectNoteRow(note: note, onPromote: { onPromote(note) })
                    }
                } else {
                    Text(String(localized: "document.crossProject.detail",
                                defaultValue: "Switch projects to view these notes."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 24)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - CrossProjectNoteRow

private struct CrossProjectNoteRow: View {
    let note: ResearchNote
    let onPromote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if note.bodyText.isEmpty {
                Text(String(localized: "document.crossProject.emptyNote",
                            defaultValue: "Empty note"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(note.bodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(String(localized: "document.crossProject.promote",
                          defaultValue: "Add to project")) {
                onPromote()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .accessibilityLabel(
                String(localized: "document.crossProject.promote.a11y",
                       defaultValue: "Add this note to the current project")
            )
        }
        .padding(.leading, 24)
        .padding(.vertical, 4)
    }
}

// MARK: - PersonDetailSheet

private struct PersonDetailSheet: View {
    let person: PersonEntry
    let mentionCount: Int
    let onFindAllMentions: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(person.name).font(.headline)
                    if let desc = person.description {
                        Text(desc).font(.body).foregroundStyle(.secondary)
                    }
                }

                Section {
                    if mentionCount > 0 {
                        Label(
                            String(
                                localized: "document.persons.mentionCount",
                                defaultValue: "Mentioned in \(mentionCount) indexed \(mentionCount == 1 ? "document" : "documents")"
                            ),
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                        Button {
                            dismiss()
                            onFindAllMentions()
                        } label: {
                            Label(
                                String(localized: "document.persons.findAll",
                                       defaultValue: "Find all mentions"),
                                systemImage: "magnifyingglass"
                            )
                        }
                        .accessibilityLabel(
                            String(localized: "document.persons.findAll.a11y",
                                   defaultValue: "Find all documents mentioning this person")
                        )
                    } else {
                        Text(String(localized: "document.persons.noMentions",
                                    defaultValue: "Not found in indexed documents"))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text(String(localized: "document.persons.section.indexed",
                                defaultValue: "In Indexed Documents"))
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(
                String(localized: "document.persons.title", defaultValue: "List of Persons")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.sheet.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
}

// MARK: - GlossDetailSheet

private struct GlossDetailSheet: View {
    let gloss: GlossEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(gloss.term).font(.headline)
                    if let def = gloss.definition {
                        Text(def).font(.body).foregroundStyle(.secondary)
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(
                String(localized: "document.terms.title", defaultValue: "Terms and Abbreviations")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.sheet.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 220)
        #endif
    }
}

// MARK: - TagPickerSheetView (iOS)

/// iOS document-level user-tag picker.
///
/// Lists all `UserTag` records from SwiftData and lets the user toggle which tags
/// apply to this document. A "New Tag" field lets the user create tags inline.
/// Presented from `DocumentView`'s toolbar "Tag Document" button.
///
/// ## Persistence
/// On appear the view reads the current tag IDs stored in `IndexingPipeline`'s
/// `document_cache` and pre-populates `selectedTagIds`. When the user taps Done,
/// the updated set is written back to both `document_cache` and the FTS5 index via
/// `IndexingPipeline.updateUserTagIds`. If `indexingPipeline` is nil (document not
/// yet indexed), the selection is a no-op and the sheet dismisses normally.
///
/// Version history:
///   1.0 — Session 120: initial implementation; replaces empty Session-14 stub
///   1.1 — Session 121: loads existing tags on appear; saves via IndexingPipeline.updateUserTagIds
///          on Done (Bug 2 — selection was stored in @State only, lost on dismiss)
///   1.2 — Session 130: `documentTaggingGeneration` increment added
private struct TagPickerSheetView: View {

    let entry: DocumentBrowserEntry
    let indexingPipeline: IndexingPipeline?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @State private var selectedTagIds: Set<UUID>
    @State private var newTagName: String = ""
    /// Tags inserted during this session — deleted if the user cancels rather than
    /// saves, preventing orphan UserTag records when Cancel is tapped.
    @State private var newlyCreatedTags: [UserTag] = []

    init(entry: DocumentBrowserEntry,
         indexingPipeline: IndexingPipeline?,
         initialTagIds: Set<UUID>) {
        self.entry = entry
        self.indexingPipeline = indexingPipeline
        _selectedTagIds = State(initialValue: initialTagIds)
    }

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Section {
                        Text(String(localized: "document.tags.empty",
                                    defaultValue: "No tags yet. Type a name below to create one."))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    Section(String(localized: "document.tags.yourTags",
                                   defaultValue: "Your Tags")) {
                        ForEach(allTags) { tag in
                            Toggle(isOn: Binding(
                                get: { selectedTagIds.contains(tag.id) },
                                set: { on in
                                    if on { selectedTagIds.insert(tag.id) }
                                    else  { selectedTagIds.remove(tag.id) }
                                }
                            )) {
                                Text(tag.name)
                            }
                        }
                    }
                }

                Section(String(localized: "document.tags.newTag",
                               defaultValue: "New Tag")) {
                    HStack {
                        TextField(
                            String(localized: "document.tags.newTag.placeholder",
                                   defaultValue: "Tag name…"),
                            text: $newTagName
                        )
                        .onSubmit { createTag() }
                        Button(
                            String(localized: "document.tags.addButton",
                                   defaultValue: "Add"),
                            action: createTag
                        )
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(
                String(
                    localized: "document.tags.sheet.title",
                    defaultValue: "Tags — \(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId)"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "document.tags.cancel",
                                  defaultValue: "Cancel")) { cancelAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.tags.done",
                                  defaultValue: "Done")) {
                        saveAndDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        newlyCreatedTags.append(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
    }

    private func cancelAndDismiss() {
        for tag in newlyCreatedTags { modelContext.delete(tag) }
        dismiss()
    }

    private func saveAndDismiss() {
        // SwiftData write and sheet dismissal happen immediately on the main thread.
        // The FTS5 virtual table update (delete + full re-insert) can take 100–500 ms
        // on iPhone storage; running it in the background eliminates the visible lag.
        syncAssignmentsToSwiftData()
        dismiss()
        guard let pipeline = indexingPipeline else { return }
        let tagString = selectedTagIds.isEmpty
            ? nil
            : selectedTagIds.map(\.uuidString).joined(separator: " ")
        let vId = entry.volumeId
        let dId = entry.documentId
        Task.detached(priority: .utility) {
            try? await pipeline.updateUserTagIds(
                volumeId: vId,
                documentId: dId,
                userTagIds: tagString
            )
        }
    }

    /// Identical to MacTagPickerSheet.syncAssignmentsToSwiftData() — see that method
    /// for documentation. Separate copy for this iOS-only private struct.
    private func syncAssignmentsToSwiftData() {
        let vId = entry.volumeId
        let dId = entry.documentId
        let descriptor = FetchDescriptor<DocumentTagAssignment>(
            predicate: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
        for assignment in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(assignment)
        }
        for tagId in selectedTagIds {
            modelContext.insert(DocumentTagAssignment(
                volumeId: vId, documentId: dId, tagId: tagId
            ))
        }
        try? modelContext.save()
    }
}

// MARK: - CollectionPickerSheetView (iOS)

/// iOS document-level collection picker.
///
/// Presents a searchable list of all collections so the user can add this document
/// to an existing collection or create a new one. Tapping a collection row inserts a
/// `CollectionEntry` and briefly shows a confirmation checkmark before auto-dismissing.
/// The "New Collection" toolbar button opens `CollectionEditorView` inline.
///
/// This is the iOS-styled counterpart of the macOS `CollectionPickerSheet` in
/// `SupportingViews.swift`. The two share identical logic; the only differences
/// are list style and the absence of a fixed frame (iOS manages size via presentation
/// detents instead).
///
/// Version history:
///   1.0 — Session 121: initial implementation (Bug 3 — iOS had no document-level
///          collection membership control)
private struct CollectionPickerSheetView: View {

    let entry: DocumentBrowserEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.lastModified, order: .reverse) private var collections: [Collection]

    @State private var searchText: String = ""
    @State private var showNewCollection = false
    @State private var addedCollectionId: UUID? = nil

    private var filtered: [Collection] {
        guard !searchText.isEmpty else { return collections }
        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "collection.picker.empty.title",
                               defaultValue: "No Collections"),
                        systemImage: "folder",
                        description: Text(
                            String(localized: "collection.picker.empty.detail",
                                   defaultValue: "Create a collection using the button above.")
                        )
                    )
                } else {
                    List(filtered) { collection in
                        Button {
                            addDocument(to: collection)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collection.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    let count = collection.documentEntries?.count ?? 0
                                    Text(
                                        String(
                                            localized: "collection.picker.documentCount",
                                            defaultValue: "\(count) \(count == 1 ? "document" : "documents")"
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if addedCollectionId == collection.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityLabel(
                                            String(localized: "collection.picker.added.a11y",
                                                   defaultValue: "Added")
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(collection.name)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $searchText,
                        prompt: String(localized: "collection.picker.search.prompt",
                                       defaultValue: "Search collections")
                    )
                }
            }
            .navigationTitle(
                String(localized: "collection.picker.title",
                       defaultValue: "Add to Collection")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.picker.cancel",
                                  defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewCollection = true
                    } label: {
                        Label(
                            String(localized: "collection.picker.newCollection",
                                   defaultValue: "New Collection"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                    .accessibilityLabel(
                        String(localized: "collection.picker.newCollection.a11y",
                               defaultValue: "Create a new collection")
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }

    private func addDocument(to collection: Collection) {
        let existing = collection.documentEntries ?? []
        // Guard against duplicates — show checkmark and dismiss if already a member.
        guard !existing.contains(where: {
            $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }) else {
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
            return
        }

        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let collectionEntry = CollectionEntry(
            collectionId: collection.id,
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            sortOrder: nextOrder
        )
        modelContext.insert(collectionEntry)
        collection.documentEntries?.append(collectionEntry)

        addedCollectionId = collection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}

#endif // os(iOS)
